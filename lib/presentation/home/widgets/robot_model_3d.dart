import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../domain/entities/robot_enums.dart';
import '../../../domain/entities/robot_status.dart';
import 'robot_illustration.dart';

const String _scenePath = 'assets/models/botdynax_scene.glb';

/// BotDyNax's own robot + dock model, driven by the real [RobotStatus].
///
/// Built procedurally (see `assets/models/build_model.mjs.txt`) rather
/// than sourced: the Sketchfab asset previously used here was an
/// exterior surface shell — one 65k-vertex mesh for the whole chassis,
/// one 59k-vertex mesh for the whole dock — so nothing could be rotated
/// or highlighted independently. Every functional part in this model is
/// its own node with its own material, and the state animations are real
/// baked glTF clips rather than CSS approximations.
///
/// Two things worth knowing about how this is driven:
///
///  * model-viewer plays exactly one clip at a time, so each clip carries
///    every channel that state needs (wheels + brushes + body motion +
///    dock visibility together). Switching state is just switching clip.
///  * Dock visibility is baked into the clips as a scale channel, so
///    `cleaning`/`idle` show the robot alone and `docking`/`undocking`/
///    `charging` show it with the station — without the scene bounds (and
///    therefore the camera framing) shifting between them.
class RobotModel3D extends StatefulWidget {
  const RobotModel3D({required this.status, super.key, this.height = 320});

  final RobotStatus status;
  final double height;

  @override
  State<RobotModel3D> createState() => _RobotModel3DState();
}

/// Maps a confirmed `total_error` code to the material name of the part
/// it belongs to. Only codes actually observed on the real W300 appear
/// here — see `TuyaFault._confirmedFaults`. Codes with no physical part
/// to point at (22 mop-washing, 13 dust-bin-installed) are deliberately
/// absent: they're informational, not a "this bit is broken" fault.
const Map<int, String> _faultMaterials = <int, String>{
  21: 'mop_pad', // mop pads removed
  46: 'dust_bin', // dust bin removed from robot
  18: 'dust_bag', // dust bag removed from dock
  24: 'clean_tank', // clean water tank removed
  25: 'sewage_tank', // sewage tank removed
};

/// Faults on parts mounted underneath, where a red pulse would otherwise
/// be facing the floor. These additionally roll the robot belly-up.
const Set<int> _undersideFaults = <int>{21};

class _RobotModel3DState extends State<RobotModel3D> {
  WebViewController? _controller;
  late final Future<bool> _modelExists;
  String? _appliedClip;
  String? _appliedFaultMaterial;

  @override
  void initState() {
    super.initState();
    _modelExists = _checkModel();
  }

  static Future<bool> _checkModel() async {
    try {
      await rootBundle.load(_scenePath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The first active fault that has a part to point at. Faults are
  /// checked in [_faultMaterials] order so the result is stable rather
  /// than depending on however the device happened to order the bitmap.
  int? get _activeFaultCode {
    for (final int code in _faultMaterials.keys) {
      if (widget.status.faultCodes.contains(code)) return code;
    }
    return null;
  }

  /// Which baked clip should be playing. An underside fault overrides the
  /// activity clip entirely — showing a red pulse on a surface pointing
  /// at the floor would be useless, so the robot rolls over instead.
  String get _targetClip {
    final int? fault = _activeFaultCode;
    if (fault != null && _undersideFaults.contains(fault)) return 'inspect_underside';
    return switch (widget.status.activity) {
      ActivityState.cleaning => 'cleaning',
      ActivityState.returningToDock => 'docking',
      ActivityState.charging => 'charging',
      ActivityState.docked => 'charging',
      ActivityState.paused || ActivityState.idle || ActivityState.error => 'idle',
    };
  }

  @override
  void didUpdateWidget(covariant RobotModel3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.activity != widget.status.activity ||
        !_sameFaults(oldWidget.status.faultCodes, widget.status.faultCodes)) {
      _apply();
    }
  }

  static bool _sameFaults(List<int> a, List<int> b) =>
      a.length == b.length && a.every(b.contains);

  void _apply() {
    final WebViewController? controller = _controller;
    if (controller == null) return;

    final String clip = _targetClip;
    final int? fault = _activeFaultCode;
    final String? faultMaterial = fault == null ? null : _faultMaterials[fault];
    if (clip == _appliedClip && faultMaterial == _appliedFaultMaterial) return;
    _appliedClip = clip;
    _appliedFaultMaterial = faultMaterial;

    final String target = faultMaterial == null ? 'null' : '"$faultMaterial"';
    unawaited(controller.runJavaScript('window.bdApply("$clip", $target);'));
  }

  /// Injected once per WebView. Holds the pulse loop and the original
  /// material colours so a cleared fault restores exactly what was there,
  /// rather than a guessed "default" colour.
  static const String _bootstrapJs = '''
    (function() {
      if (window.bdApply) return;
      const mv = document.querySelector("model-viewer");
      let base = null, timer = null, targetName = null;

      function snapshot() {
        if (base || !mv.model) return;
        base = new Map();
        for (const m of mv.model.materials) {
          if (m.pbrMetallicRoughness) {
            base.set(m.name, Array.from(m.pbrMetallicRoughness.baseColorFactor));
          }
        }
      }
      function restoreAll() {
        if (!base || !mv.model) return;
        for (const m of mv.model.materials) {
          const b = base.get(m.name);
          if (b && m.pbrMetallicRoughness) m.pbrMetallicRoughness.setBaseColorFactor(b);
        }
      }
      window.bdApply = function(clip, faultMaterial) {
        if (!mv.model) { setTimeout(() => window.bdApply(clip, faultMaterial), 150); return; }
        snapshot();
        if (mv.animationName !== clip) { mv.animationName = clip; }
        mv.play();

        if (timer) { clearInterval(timer); timer = null; }
        restoreAll();
        targetName = faultMaterial;
        if (!targetName) return;
        const t0 = performance.now();
        timer = setInterval(() => {
          if (!mv.model) return;
          const k = 0.5 + 0.5 * Math.sin((performance.now() - t0) / 260);
          for (const m of mv.model.materials) {
            if (m.name !== targetName || !m.pbrMetallicRoughness) continue;
            const b = base.get(m.name);
            if (!b) continue;
            m.pbrMetallicRoughness.setBaseColorFactor([
              b[0] + (1 - b[0]) * k,
              b[1] + (0.18 - b[1]) * k,
              b[2] + (0.25 - b[2]) * k,
              b[3],
            ]);
          }
        }, 33);
      };
    })();
  ''';

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
            // Asset missing — fall back to the 2D illustration rather
            // than showing an empty box.
            return Center(child: RobotIllustration(status: widget.status));
          }
          return ModelViewer(
            src: _scenePath,
            alt: 'BotDyNax robot vacuum and docking station',
            backgroundColor: Colors.transparent,
            // `loading: eager` matters: the default lazy mode waits on an
            // IntersectionObserver that never fires reliably inside an
            // embedded WebView, leaving the model permanently unloaded.
            loading: Loading.eager,
            reveal: Reveal.auto,
            autoPlay: true,
            // Declare the clip up front. With autoPlay alone, model-viewer
            // starts whichever clip is first in the file ('cleaning',
            // which hides the dock) and only switches once the injected
            // JS runs — so a docked robot briefly, or on a slow WebView
            // permanently, rendered with no dock beside it.
            animationName: _targetClip,
            cameraControls: true,
            disableZoom: true,
            cameraOrbit: '28deg 66deg 105%',
            minCameraOrbit: 'auto auto 0.4m',
            shadowIntensity: 0.9,
            shadowSoftness: 0.7,
            exposure: 1.1,
            debugLogging: false,
            relatedJs: _bootstrapJs,
            onWebViewCreated: (WebViewController controller) {
              _controller = controller;
              _appliedClip = null;
              _appliedFaultMaterial = null;
              _apply();
            },
          );
        },
      ),
    );
  }
}
