import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../domain/entities/robot_enums.dart';
import '../../../domain/entities/robot_status.dart';
import 'robot_illustration.dart';

const String _modelAssetPath = 'assets/models/robot_vacuum.glb';

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
/// actually rendering the model with each one isolated in a bright color
/// (see the investigation this widget's history came from) — the model
/// has a badge/button decal and a sensor-window pane as separately
/// materialed parts, but nothing corresponding to a dust bin, mop pad, or
/// water tank; the rest of the body is arbitrary shading-material splits
/// with no functional meaning. So fault indication here is a whole-model
/// red tint rather than the 2D illustration's per-component highlighting
/// — the exact cause still shows via the existing text fault banner
/// elsewhere on the dashboard.
///
/// Falls back to an honest "not installed" placeholder rather than
/// crashing if `assets/models/robot_vacuum.glb` hasn't been added yet.
class RobotModel3D extends StatefulWidget {
  const RobotModel3D({required this.status, super.key, this.height = 260});

  final RobotStatus status;
  final double height;

  @override
  State<RobotModel3D> createState() => _RobotModel3DState();
}

class _RobotModel3DState extends State<RobotModel3D> {
  WebViewController? _webViewController;
  late final Future<bool> _modelExists;

  @override
  void initState() {
    super.initState();
    _modelExists = _checkModelExists();
  }

  static Future<bool> _checkModelExists() async {
    try {
      await rootBundle.load(_modelAssetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant RobotModel3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.activity != widget.status.activity ||
        oldWidget.status.hasErrors != widget.status.hasErrors ||
        oldWidget.status.cleaningType != widget.status.cleaningType) {
      _applySceneState();
    }
  }

  /// Re-applies rotation speed, cleaning motion, and fault tint via the
  /// model-viewer JS scene-graph API
  /// (https://modelviewer.dev/docs/#entrydocs-scenegraph) whenever
  /// activity/fault state changes.
  ///
  /// There's no way to isolate and spin just a brush/mop part (this asset
  /// has no such separable geometry, and model-viewer's stable API only
  /// exposes materials, not per-node transforms) — so "the robot is
  /// working" is instead conveyed with a real CSS keyframe animation on
  /// the whole model: a quick side-to-side jitter for vacuuming, a
  /// slower rocking sway for mopping, distinguished so the two read
  /// differently rather than being one generic wiggle.
  void _applySceneState() {
    final WebViewController? controller = _webViewController;
    if (controller == null) return;

    final bool isCleaning = widget.status.activity == ActivityState.cleaning;
    final bool isFaulted = widget.status.hasErrors;
    final String colorFactor = isFaulted ? '[1, 0.25, 0.3, 1]' : '[1, 1, 1, 1]';
    final bool isMopping = widget.status.cleaningType == CleaningType.mop ||
        widget.status.cleaningType == CleaningType.mopAfterVacuum;
    final String motionClass = !isCleaning ? '' : (isMopping ? 'bd-mop' : 'bd-vacuum');

    unawaited(controller.runJavaScript('''
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
        future: _modelExists,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            // 3D asset not installed yet (see assets/models/README.md) --
            // fall back to the fully-featured 2D vector illustration
            // rather than a bare placeholder, so fault highlighting still
            // works in the meantime.
            return Center(child: RobotIllustration(status: widget.status));
          }
          return ModelViewer(
            key: const ValueKey(_modelAssetPath),
            src: _modelAssetPath,
            alt: 'BotDyNax robot vacuum 3D model',
            backgroundColor: Colors.transparent,
            autoRotate: widget.status.activity == ActivityState.cleaning,
            rotationPerSecond: widget.status.activity == ActivityState.cleaning ? '60deg' : '8deg',
            cameraControls: true,
            shadowIntensity: 0.6,
            exposure: 1.0,
            debugLogging: false,
            onWebViewCreated: (WebViewController controller) {
              _webViewController = controller;
              _applySceneState();
            },
          );
        },
      ),
    );
  }
}
