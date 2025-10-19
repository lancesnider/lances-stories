// lib/util/parallax_tilt_fused.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TiltAngles {
  final double x, y, z; // radians; x ~ pitch, z ~ roll
  const TiltAngles(this.x, this.y, this.z);
}

class ParallaxTiltFused extends StatefulWidget {
  const ParallaxTiltFused({
    super.key,
    this.enabled = true,
    this.alpha = 0.95,
    this.samplingPeriod = const Duration(milliseconds: 10),
    required this.onAngles,           // ← NEW: push updates out
    this.child,                       // ← NEW: keep a static child (no rebuilds)
  });

  final bool enabled;
  final double alpha;
  final Duration samplingPeriod;
  final void Function(TiltAngles angles) onAngles; // ← NEW
  final Widget? child;                              // ← NEW

  @override
  State<ParallaxTiltFused> createState() => _ParallaxTiltFusedState();
}

class _ParallaxTiltFusedState extends State<ParallaxTiltFused> {
  double _roll = 0.0, _pitch = 0.0;
  double _accRoll = 0.0, _accPitch = 0.0;
  DateTime? _lastGyroTime;

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _startStreams();
  }

  @override
  void didUpdateWidget(covariant ParallaxTiltFused old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled ||
        old.samplingPeriod != widget.samplingPeriod ||
        old.alpha != widget.alpha) {
      _stopStreams();
      if (widget.enabled) _startStreams();
    }
  }

  void _startStreams() {
    _lastGyroTime = null;

    _accSub = accelerometerEventStream(
      samplingPeriod: widget.samplingPeriod,
    ).listen((a) {
      final ax = a.x, ay = a.y, az = a.z;
      _accRoll  = math.atan2(ay, az);
      _accPitch = math.atan2(-ax, math.sqrt(ay * ay + az * az));
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: widget.samplingPeriod,
    ).listen((g) {
      final now = DateTime.now();
      final last = _lastGyroTime ?? now;
      final dt = (now.difference(last).inMicroseconds / 1e6).clamp(0.0001, 0.05);
      _lastGyroTime = now;

      _roll  += g.x * dt;
      _pitch += g.y * dt;

      final a = widget.alpha;
      _roll  = a * _roll  + (1 - a) * _accRoll;
      _pitch = a * _pitch + (1 - a) * _accPitch;

      // NO setState(): push values out to the parent
      widget.onAngles(TiltAngles(_pitch, 0.0, _roll));
    });
  }

  void _stopStreams() {
    _accSub?.cancel(); _accSub = null;
    _gyroSub?.cancel(); _gyroSub = null;
  }

  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Static child; doesn’t rebuild on sensor ticks
    return widget.child ?? const SizedBox.shrink();
  }
}
