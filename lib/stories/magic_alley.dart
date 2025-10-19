import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:lances_stories/util/parallax_fusion_controller.dart';

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

  // Fusion controller (no rebuilds)
  late final TiltFusionController _tilt = TiltFusionController(
    alpha: 0.95,                                   // tweak feel
    samplingPeriod: const Duration(milliseconds: 8), // ~125 Hz
  );

  // mapping & jitter helpers
  double _mapRange(double v, double inMin, double inMax, double outMin, double outMax) {
    final t = ((v - inMin) / (inMax - inMin)).clamp(0.0, 1.0);
    return outMin + t * (outMax - outMin);
  }

  static const double _center = 50.0;
  static const double _deadzone = 1.2; // ±1.2 around center
  static const double _quant = 0.25;   // snap to 0.25
  static const int _minMsBetweenSends = 8; // cap to ~125 Hz

  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  double _deadzoneFn(double v) =>
      (v - _center).abs() <= _deadzone ? _center : v;
  double _quantize(double v) => (v / _quant).roundToDouble() * _quant;

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

    // Start sensors AFTER view model exists, and listen without rebuilding UI.
    _tilt.start();
    _tilt.angles.addListener(_onTilt);

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

  // No setState here—just write to Rive
  void _onTilt() {
    final a = _tilt.angles.value; // radians; x=pitch, z=roll

    // Map a comfortable band (≈ ±1.0 rad) to 0..100
    var x = _mapRange(a.x, -1.0, 1.0, 0, 100);
    var y = _mapRange(a.z, -1.0, 1.0, 0, 100);

    // tame shimmer a bit
    x = _quantize(_deadzoneFn(x));
    y = _quantize(_deadzoneFn(y));

    // rate-limit writes so we don't spam Rive
    final now = DateTime.now();
    if (now.difference(_lastSent).inMilliseconds >= _minMsBetweenSends) {
      parallaxX.value = x.clamp(0, 100);
      parallaxY.value = y.clamp(0, 100);
      _lastSent = now;
    }
  }

  void _maybeUpdateSize(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;
    windowWidth.value = size.width;
    windowHeight.value = size.height;
  }

  @override
  void dispose() {
    _tilt.angles.removeListener(_onTilt);
    _tilt.dispose();
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
          onDoubleTapDown: (_) => _tilt.zeroToCurrent(), // calibrate to current pose
          child: RiveWidget(
            controller: controller,
            fit: Fit.layout,
            layoutScaleFactor: .421,
          ),
        );
      },
    );
  }
}
