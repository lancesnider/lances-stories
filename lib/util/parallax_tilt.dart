import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Simple data holder for current tilt angles.
class TiltAngles {
  final double x, y, z;
  const TiltAngles(this.x, this.y, this.z);
}

/// Reusable tilt widget.
/// - Listens to `accelerometerEventStream()`
/// - Animates changes with a tween (same “feel” as your original)
/// - Exposes animated angles to your UI via [builder]
class ParallaxTilt extends StatefulWidget {
  const ParallaxTilt({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
  });

  final Widget Function(BuildContext context, TiltAngles angles) builder;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  @override
  State<ParallaxTilt> createState() => _ParallaxTiltState();
}

class _ParallaxTiltState extends State<ParallaxTilt> {
  // Previous (for tween start) + latest raw values
  double _x = 0, _px = 0;
  double _y = 0, _py = 0;
  double _z = 0, _pz = 0;

  StreamSubscription<AccelerometerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _sub = accelerometerEventStream().listen((e) {
        if (!mounted) return;
        setState(() {
          _px = _x; _x = e.x;
          _py = _y; _y = e.y;
          _pz = _z; _z = e.z;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant ParallaxTilt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _sub?.cancel();
      _sub = null;
      if (widget.enabled) {
        _sub = accelerometerEventStream().listen((e) {
          if (!mounted) return;
          setState(() {
            _px = _x; _x = e.x;
            _py = _y; _y = e.y;
            _pz = _z; _z = e.z;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the original “nested TweenAnimationBuilder” feel (X then Z).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _px, end: _x),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, xValue, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: _pz, end: _z),
          duration: widget.duration,
          curve: widget.curve,
          builder: (context, zValue, __) {
            // Y is available if you ever need it; animate like X/Z if desired.
            return widget.builder(context, TiltAngles(xValue, _y, zValue));
          },
        );
      },
    );
  }
}
