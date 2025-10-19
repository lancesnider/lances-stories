import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:lances_stories/util/parallax_tilt_fused.dart'; // fused orientation widget

class MagicAlley extends StatefulWidget {
  const MagicAlley({super.key});

  @override
  State<MagicAlley> createState() => _MagicAlleyState();
}

class _MagicAlleyState extends State<MagicAlley> {
  late File file;
  late RiveWidgetController controller;
  bool isInitialized = false;

  late ViewModelInstance viewModelInstance;

  late ViewModelInstanceNumber sceneWidth;
  late ViewModelInstanceNumber sceneHeight;
  late ViewModelInstanceNumber windowWidth;
  late ViewModelInstanceNumber windowHeight;
  late ViewModelInstanceNumber parallaxX;
  late ViewModelInstanceNumber parallaxY;

  Size? _lastSize;

  // For calibration (double-tap to zero current pose)
  double _zeroPitch = 0.0; // baseline for ang.x
  double _zeroRoll  = 0.0; // baseline for ang.z
  TiltAngles? _lastAngles;

  @override
  void initState() {
    super.initState();
    _initRive();
  }

  Future<void> _initRive() async {
    file = (await File.asset(
      "assets/rive/magic_alley_12.riv",
      riveFactory: Factory.rive,
    ))!;
    controller = RiveWidgetController(file);
    _initViewModel();
    setState(() => isInitialized = true);
  }

  void _initViewModel() {
    viewModelInstance = controller.dataBind(DataBind.auto());
    ViewModelInstanceNumber needNum(String name) {
      final v = viewModelInstance.number(name);
      if (v == null) {
        throw StateError('ViewModel number "$name" not found. Export it in the Rive file.');
      }
      return v;
    }

    sceneWidth  = needNum('sceneWidth');
    sceneHeight = needNum('sceneHeight');
    windowWidth = needNum('windowWidth');
    windowHeight = needNum('windowHeight');
    parallaxX   = needNum('parallaxX');
    parallaxY   = needNum('parallaxY');
  }

  void _maybeUpdateSize(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;
    windowWidth.value = size.width;
    windowHeight.value = size.height;
  }

  @override
  void dispose() {
    controller.dispose();
    file.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _maybeUpdateSize(size);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (_) {
            final a = _lastAngles;
            if (a != null) {
              setState(() { // occasional rebuild only on calibration
                _zeroPitch = a.x;
                _zeroRoll  = a.z;
              });
            }
          },
          child: ParallaxTiltFused(
            alpha: 0.95,
            samplingPeriod: const Duration(milliseconds: 10),
            onAngles: (ang) {
              _lastAngles = ang;
              final pitch = ang.x - _zeroPitch;
              final roll  = ang.z - _zeroRoll;

              // write directly to Rive — no setState
              parallaxX.value = pitch.clamp(-.3, .3);
              parallaxY.value = roll.clamp(-.3, .3);
            },
            child: RiveWidget( // static child, built once
              controller: controller,
              fit: Fit.layout,
              layoutScaleFactor: .421,
            ),
          ),
        );
      },
    );
  }
}
