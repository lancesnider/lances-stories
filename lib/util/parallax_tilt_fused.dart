// lib/util/parallax_tilt_fused.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Simple data holder for current tilt angles (radians).
/// x ~ pitch, z ~ roll. y is unused here but kept for parity.
class TiltAngles {
  final double x, y, z;
  const TiltAngles(this.x, this.y, this.z);
}

/// Fused orientation (accelerometer + gyroscope) with a complementary filter.
/// This version uses a Duration samplingPeriod (older sensors_plus API).
class ParallaxTiltFused extends StatefulWidget {
  const ParallaxTiltFused({
    super.key,
    required this.builder,
    this.enabled = true,
    this.alpha = 0.95, // 0.90–0.98; higher = snappier, lower = steadier
    this.samplingPeriod = const Duration(milliseconds: 10), // ~100 Hz
  });

  final Widget Function(BuildContext, TiltAngles) builder;
  final bool enabled;
  final double alpha;
  final Duration samplingPeriod;

  @override
  State<ParallaxTiltFused> createState() => _ParallaxTiltFusedState();
}

class _ParallaxTiltFusedState extends State<ParallaxTiltFused> {
  // Integrated angles (radians)
  double _roll = 0.0;   // around X
  double _pitch = 0.0;  // around Y

  // Latest accel-derived angles (radians)
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
  void didUpdateWidget(covariant ParallaxTiltFused oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.samplingPeriod != widget.samplingPeriod ||
        oldWidget.alpha != widget.alpha) {
      _stopStreams();
      if (widget.enabled) _startStreams();
    }
  }

  void _startStreams() {
    _lastGyroTime = null;

    // Accelerometer: estimate absolute roll/pitch from gravity vector.
    _accSub = accelerometerEventStream(
      samplingPeriod: widget.samplingPeriod, // Duration ✅
    ).listen((a) {
      final ax = a.x, ay = a.y, az = a.z;
      // roll = atan2(ay, az), pitch = atan2(-ax, sqrt(ay^2 + az^2))
      _accRoll  = math.atan2(ay, az);
      _accPitch = math.atan2(-ax, math.sqrt(ay * ay + az * az));
    });

    // Gyro: integrate angular velocity, fuse with accel via complementary filter.
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: widget.samplingPeriod, // Duration ✅
    ).listen((g) {
      final now = DateTime.now();
      final last = _lastGyroTime ?? now;
      final dt = (now.difference(last).inMicroseconds / 1e6).clamp(0.0001, 0.05);
      _lastGyroTime = now;

      // Integrate gyro (rad/s * s = rad)
      _roll  += g.x * dt;
      _pitch += g.y * dt;
      _yaw   += g.z * dt;

      // Complementary filter fuse
      final a = widget.alpha;
      _roll  = a * _roll  + (1 - a) * _accRoll;
      _pitch = a * _pitch + (1 - a) * _accPitch;

      if (mounted) setState(() {});
    });
  }

  void _stopStreams() {
    _accSub?.cancel();
    _gyroSub?.cancel();
    _accSub = null;
    _gyroSub = null;
  }

  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Expose pitch (x) and roll (z). y is unused but kept for API symmetry.
    return widget.builder(context, TiltAngles(_pitch, 0.0, _roll));
  }
}
