import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/widgets/brand_logo.dart';
import '../../../domain/entities/robot_enums.dart';
import '../../../domain/entities/robot_status.dart';
import 'robot_illustration.dart';

const String _dockedScenePath = 'assets/models/robot_vacuum.glb';
const String _robotOnlyPath = 'assets/models/robot_only.glb';

/// Displays the robot as a real, interactive glTF/GLB 3D model (rendered
/// via `<model-viewer>` in an embedded WebView), driven by the same real
/// [RobotStatus] the rest of the app reads off the decoded Tuya status.
///
/// Model credit: "Robot vacuum Cleaner Rob-vac" by darkfrei on Sketchfab,
/// licensed CC-BY 4.0 —
/// https://sketchfab.com/3d-models/robot-vacuum-cleaner-rob-vac-7d904c05d4204d19a2940d9d6f21ef8d
///
/// This is a generic stock asset, not a scan of the real Milagrow W300 —
/// same "abstract, not a literal product photo" honesty as the 2D
/// [RobotIllustration] it sits alongside. Its 16 materials were mapped by
/// actually rendering the model with each one isolated in a bright color —
/// the model has a badge/button decal and a sensor-window pane as
/// separately materialed parts, but nothing corresponding to a dust bin,
/// mop pad, or water tank; the rest of the body is arbitrary shading-
/// material splits with no functional meaning. So fault indication here
/// is a whole-model red tint rather than the 2D illustration's
/// per-component highlighting — the exact cause still shows via the
/// existing text fault banner elsewhere on the dashboard.
///
/// The original file contains both the dock and the robot as one scene.
/// [_robotOnlyPath] is a second asset split out of it (by clustering every
/// mesh's real world-space position — not a guess) containing only the
/// robot's 42 nodes, recentered to the origin, so the robot can be shown
/// on its own once it's left the dock.
///
/// Docking/undocking is a real camera-choreographed transition, not a
/// plain file swap: model-viewer natively animates `cameraTarget`/
/// `cameraOrbit` changes (https://modelviewer.dev/docs/#entrydocs-
/// stagingandcameras-attributes-cameraOrbit — "any time this value
/// changes... the camera will interpolate"), so leaving the dock zooms
/// the camera in on the robot within the docked scene first, THEN swaps
/// to [_robotOnlyPath] once framed tightly enough that the swap itself
/// is imperceptible, then eases out to a comfortable framing. Returning
/// to the dock runs the same thing in reverse. The exact camera values
/// were tuned empirically against the real rendered models (not
/// guessed) so the cut between the two files lines up.
///
/// Falls back to the 2D [RobotIllustration] rather than crashing if
/// either asset hasn't been added yet.
///
/// The source asset had a raised "xiaomi" wordmark embossed into the top
/// shell (real geometry, not a texture — confirmed via
/// `model-viewer.materialFromPoint()` raycasting on the actual rendered
/// pixels, which identified it as its own material/mesh, isolated to
/// exactly those six letters and nothing else). That mesh has been
/// deleted from both .glb files; a small [BrandLogo] watermark is
/// composited on top of the viewer instead, since there's no texture
/// system in this model to bake a replacement decal into the geometry.
class RobotModel3D extends StatefulWidget {
  const RobotModel3D({required this.status, super.key, this.height = 260});

  final RobotStatus status;
  final double height;

  @override
  State<RobotModel3D> createState() => _RobotModel3DState();
}

bool _isAtOrApproachingDock(ActivityState activity) =>
    activity == ActivityState.returningToDock ||
    activity == ActivityState.docked ||
    activity == ActivityState.charging;

// Tuned empirically in a browser against the real rendered .glb files
// (see the model_viewer_plus investigation this widget's history came
// from) so the docked-scene <-> robot-only cut lines up and the tight
// framing actually isolates the robot rather than clipping into it.
const String _robotFocusTarget = '0.6488m -0.63m 0.02m';
const String _minOrbitRadius = 'auto auto 0.3m';
const String _tightOrbitInScene = '0deg 65deg 0.55m';
const String _tightOrbitRobotOnly = '0deg 65deg 0.65m';
const String _settledOrbitRobotOnly = '0deg 68deg 100%';
const String _wideOrbit = '10deg 70deg 105%';

const Duration _focusDuration = Duration(milliseconds: 750);
const Duration _renderSettleDuration = Duration(milliseconds: 120);

class _RobotModel3DState extends State<RobotModel3D> {
  WebViewController? _webViewController;
  late final Future<bool> _modelsExist;
  late bool _isDocked = _isAtOrApproachingDock(widget.status.activity);

  /// Which .glb is actually loaded in the WebView right now — tracked
  /// separately from [widget.status] because the dock transition changes
  /// this mid-flight, ahead of (and independent of) further status ticks.
  late String _loadedSrc = _isDocked ? _dockedScenePath : _robotOnlyPath;

  /// Bumped on every dock-state change so an in-flight transition can
  /// tell it's been superseded (e.g. the robot immediately leaves again
  /// before the "arriving" animation finished) and stop issuing further
  /// JS instead of fighting a newer transition for control of the camera.
  int _transitionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _modelsExist = _checkModelsExist();
  }

  static Future<bool> _checkModelsExist() async {
    try {
      await rootBundle.load(_dockedScenePath);
      await rootBundle.load(_robotOnlyPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant RobotModel3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool isDocked = _isAtOrApproachingDock(widget.status.activity);
    if (isDocked != _isDocked) {
      _isDocked = isDocked;
      unawaited(_playDockTransition(enteringDock: isDocked));
      return;
    }
    if (oldWidget.status.activity != widget.status.activity ||
        oldWidget.status.hasErrors != widget.status.hasErrors ||
        oldWidget.status.cleaningType != widget.status.cleaningType) {
      _applySceneState();
    }
  }

  Future<void> _run(String js) async {
    final WebViewController? controller = _webViewController;
    if (controller == null) return;
    await controller.runJavaScript(js);
  }

  /// Camera-choreographed dock/undock. See the class doc for why this is
  /// a staged camera move + mid-flight file swap rather than a plain
  /// crossfade: model-viewer can't smoothly interpolate between the
  /// geometry of two different loaded files, but it CAN smoothly animate
  /// its camera, so the trick is timing the swap for the moment the
  /// camera is already framed tightly enough that the cut disappears.
  Future<void> _playDockTransition({required bool enteringDock}) async {
    final int generation = ++_transitionGeneration;
    bool stillCurrent() => generation == _transitionGeneration && mounted;

    if (enteringDock) {
      // Currently on robot_only (settled or tight, doesn't matter) ->
      // tighten to match the docked scene's framing -> swap -> pull back
      // to reveal the dock, like the camera backing away as the robot
      // settles onto the station.
      await _run('''
        (function() {
          const mv = document.querySelector("model-viewer");
          if (!mv) return;
          mv.minCameraOrbit = "$_minOrbitRadius";
          mv.cameraTarget = "auto";
          mv.cameraOrbit = "$_tightOrbitRobotOnly";
        })();
      ''');
      await Future<void>.delayed(_focusDuration);
      if (!stillCurrent()) return;

      _loadedSrc = _dockedScenePath;
      await _run('''
        (function() {
          const mv = document.querySelector("model-viewer");
          if (!mv) return;
          mv.src = "$_dockedScenePath";
          mv.minCameraOrbit = "$_minOrbitRadius";
          mv.cameraTarget = "$_robotFocusTarget";
          mv.cameraOrbit = "$_tightOrbitInScene";
          mv.jumpCameraToGoal();
        })();
      ''');
      await Future<void>.delayed(_renderSettleDuration);
      if (!stillCurrent()) return;

      await _run('''
        (function() {
          const mv = document.querySelector("model-viewer");
          if (!mv) return;
          mv.cameraTarget = "auto";
          mv.cameraOrbit = "$_wideOrbit";
        })();
      ''');
    } else {
      // Currently on the docked scene, wide framing -> zoom in on just
      // the robot -> swap to robot_only at matching framing (the robot
      // "stepping out" of frame, dock left behind) -> settle to a
      // comfortable single-robot view for the cleaning run ahead.
      await _run('''
        (function() {
          const mv = document.querySelector("model-viewer");
          if (!mv) return;
          mv.minCameraOrbit = "$_minOrbitRadius";
          mv.cameraTarget = "$_robotFocusTarget";
          mv.cameraOrbit = "$_tightOrbitInScene";
        })();
      ''');
      await Future<void>.delayed(_focusDuration);
      if (!stillCurrent()) return;

      _loadedSrc = _robotOnlyPath;
      await _run('''
        (function() {
          const mv = document.querySelector("model-viewer");
          if (!mv) return;
          mv.src = "$_robotOnlyPath";
          mv.minCameraOrbit = "$_minOrbitRadius";
          mv.cameraTarget = "auto";
          mv.cameraOrbit = "$_tightOrbitRobotOnly";
          mv.jumpCameraToGoal();
        })();
      ''');
      await Future<void>.delayed(_renderSettleDuration);
      if (!stillCurrent()) return;

      await _run('''
        (function() {
          const mv = document.querySelector("model-viewer");
          if (!mv) return;
          mv.cameraTarget = "auto";
          mv.cameraOrbit = "$_settledOrbitRobotOnly";
        })();
      ''');
    }
    if (stillCurrent()) _applySceneState();
  }

  /// Re-applies rotation speed, cleaning motion, and fault tint via the
  /// model-viewer JS scene-graph API
  /// (https://modelviewer.dev/docs/#entrydocs-scenegraph) whenever
  /// activity/fault state changes. Purely material/rotation-speed —
  /// never touches camera framing, so it can't fight [_playDockTransition]
  /// for control of the shot.
  ///
  /// There's no way to isolate and spin just a brush/mop part (this asset
  /// has no such separable geometry, and model-viewer's stable API only
  /// exposes materials, not per-node transforms) — so "the robot is
  /// working" is instead conveyed with a real CSS keyframe animation on
  /// the whole model: a quick side-to-side jitter for vacuuming, a
  /// slower rocking sway for mopping, distinguished so the two read
  /// differently rather than being one generic wiggle.
  void _applySceneState() {
    final bool isCleaning = widget.status.activity == ActivityState.cleaning;
    final bool isFaulted = widget.status.hasErrors;
    final String colorFactor = isFaulted ? '[1, 0.25, 0.3, 1]' : '[1, 1, 1, 1]';
    final bool isMopping = widget.status.cleaningType == CleaningType.mop ||
        widget.status.cleaningType == CleaningType.mopAfterVacuum;
    final String motionClass = !isCleaning ? '' : (isMopping ? 'bd-mop' : 'bd-vacuum');

    unawaited(_run('''
      (function() {
        const mv = document.querySelector("model-viewer");
        if (!mv) return;

        if (!document.getElementById("bd-motion-style")) {
          const style = document.createElement("style");
          style.id = "bd-motion-style";
          style.textContent = `
            @keyframes bd-vacuum-anim {
              0%, 100% { transform: translateX(0) rotate(0deg); }
              25% { transform: translateX(-3px) rotate(-0.6deg); }
              75% { transform: translateX(3px) rotate(0.6deg); }
            }
            @keyframes bd-mop-anim {
              0%, 100% { transform: translateX(0) rotate(0deg); }
              50% { transform: translateX(6px) rotate(1.2deg); }
            }
            model-viewer.bd-vacuum { animation: bd-vacuum-anim 0.35s ease-in-out infinite; }
            model-viewer.bd-mop { animation: bd-mop-anim 1.1s ease-in-out infinite; }
          `;
          document.head.appendChild(style);
        }
        mv.classList.remove("bd-vacuum", "bd-mop");
        ${motionClass.isNotEmpty ? 'mv.classList.add("$motionClass");' : ''}

        mv.autoRotate = $isCleaning;
        mv.rotationPerSecond = "${isCleaning ? '60deg' : '8deg'}";
        if (mv.model && mv.model.materials) {
          mv.model.materials.forEach((m) => {
            if (m.pbrMetallicRoughness) m.pbrMetallicRoughness.setBaseColorFactor($colorFactor);
          });
        }
      })();
    '''));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: FutureBuilder<bool>(
        future: _modelsExist,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            // 3D assets not installed yet (see assets/models/README.md) --
            // fall back to the fully-featured 2D vector illustration
            // rather than a bare placeholder, so fault highlighting still
            // works in the meantime.
            return Center(child: RobotIllustration(status: widget.status));
          }
          return Stack(
            children: [
              // No ValueKey(src) here on purpose -- this widget/WebView
              // must stay mounted across dock/undock so
              // _playDockTransition can drive `mv.src` itself, timed
              // against the camera animation. [_loadedSrc] (fixed at
              // first build) is only the INITIAL file; every change after
              // that goes through JS, not through rebuilding this widget.
              ModelViewer(
                src: _loadedSrc,
                alt: 'BotDyNax robot vacuum 3D model',
                backgroundColor: Colors.transparent,
                cameraTarget: 'auto',
                cameraOrbit: _isDocked ? _wideOrbit : _settledOrbitRobotOnly,
                minCameraOrbit: _minOrbitRadius,
                autoRotate: widget.status.activity == ActivityState.cleaning,
                rotationPerSecond: widget.status.activity == ActivityState.cleaning ? '60deg' : '8deg',
                cameraControls: true,
                disableZoom: true,
                shadowIntensity: 0.6,
                exposure: 1.0,
                debugLogging: false,
                onWebViewCreated: (WebViewController controller) {
                  _webViewController = controller;
                  _applySceneState();
                },
              ),
              // Where the source model's "xiaomi" mesh used to sit
              // (now deleted) — a flat UI overlay rather than baked-in
              // geometry, since this model has no texture system to
              // stamp a replacement decal into.
              const Positioned(
                top: 8,
                right: 8,
                child: Opacity(opacity: 0.85, child: BrandLogo(height: 18)),
              ),
            ],
          );
        },
      ),
    );
  }
}
