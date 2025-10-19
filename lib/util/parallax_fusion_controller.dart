// lib/util/tilt_fusion_controller.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TiltAngles {
  final double x, y, z; // radians; x ~ pitch, z ~ roll
  const TiltAngles(this.x, this.y, this.z);
}

class TiltFusionController {
  TiltFusionController({
    this.alpha = 0.95, // 0.90–0.98; higher = snappier
    this.samplingPeriod = const Duration(milliseconds: 10), // ~100 Hz
  });

  final double alpha;
  final Duration samplingPeriod;

  final ValueNotifier<TiltAngles> angles = ValueNotifier(const TiltAngles(0, 0, 0));

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // fused state
  double _roll = 0.0;   // around X
  double _pitch = 0.0;  // around Y
  double _yaw = 0.0;    // around Z (unused)
  double _accRoll = 0.0, _accPitch = 0.0;
  DateTime? _lastGyroTime;

  // calibration offsets
  double _zeroPitch = 0.0;
  double _zeroRoll  = 0.0;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _lastGyroTime = null;

    _accSub = accelerometerEventStream(samplingPeriod: samplingPeriod).listen((a) {
      final ax = a.x, ay = a.y, az = a.z;
      _accRoll  = math.atan2(ay, az);
      _accPitch = math.atan2(-ax, math.sqrt(ay * ay + az * az));
    });

    _gyroSub = gyroscopeEventStream(samplingPeriod: samplingPeriod).listen((g) {
      final now = DateTime.now();
      final last = _lastGyroTime ?? now;
      final dt = (now.difference(last).inMicroseconds / 1e6).clamp(0.0001, 0.05);
      _lastGyroTime = now;

      // integrate gyro
      _roll  += g.x * dt;
      _pitch += g.y * dt;
      _yaw   += g.z * dt;

      // complementary fuse
      final a = alpha;
      _roll  = a * _roll  + (1 - a) * _accRoll;
      _pitch = a * _pitch + (1 - a) * _accPitch;

      // publish (apply calibration before notifying)
      angles.value = TiltAngles(_pitch - _zeroPitch, 0.0, _roll - _zeroRoll);
    });
  }

  void zeroToCurrent() {
    // set calibration to current fused pose
    _zeroPitch = _pitch;
    _zeroRoll  = _roll;
  }

  void stop() {
    _running = false;
    _accSub?.cancel(); _accSub = null;
    _gyroSub?.cancel(); _gyroSub = null;
  }

  void dispose() {
    stop();
    angles.dispose();
  }
}
