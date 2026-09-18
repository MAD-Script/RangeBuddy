import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// Uses the accelerometer to detect when the device is genuinely
/// stationary, independent of how the phone is mounted on the bike.
///
/// IMPORTANT — scope of what this does and doesn't do:
/// This does NOT do full inertial dead-reckoning (integrating
/// acceleration to estimate speed/distance between GPS fixes). That
/// would require knowing which axis on the phone points "forward",
/// which needs a one-time mount-orientation calibration step (hold
/// the phone still, accelerate in a straight line, solve for the
/// rotation) — a real feature, but a separate one, and not something
/// to bolt on silently. Guessing at "forward" from an uncalibrated
/// mount would produce confidently wrong numbers, which is worse than
/// not having the feature.
///
/// What this DOES do, correctly and without needing orientation: look
/// at the VARIANCE of raw acceleration magnitude over a short rolling
/// window. Magnitude is orientation-independent — "no motion in any
/// axis" reads the same however the phone is mounted. This is the
/// classic zero-velocity detection (ZUPT) technique used in inertial
/// navigation to correct drift. Here it's used for one concrete thing:
/// catching the case where the bike is genuinely stopped at a light
/// but GPS speed is showing noisy 3-5km/h "creep" from drift — which
/// otherwise pollutes stop-count and congestion-overhead calibration.
class MotionDetector {
  static const _windowSize = 12; // ~0.5-1s depending on device sensor rate
  static const _stationaryVarianceThreshold = 0.05; // (m/s^2)^2, empirical

  final List<double> _recentMagnitudes = [];
  StreamSubscription<UserAccelerometerEvent>? _sub;
  bool _isStationary = false;

  /// True once enough samples have been seen to make a confident call.
  /// Before that, callers should trust GPS speed alone.
  bool get hasEnoughData => _recentMagnitudes.length >= _windowSize;

  bool get isStationary => _isStationary;

  void start() {
    _recentMagnitudes.clear();
    _isStationary = false;
    _sub = userAccelerometerEventStream().listen((event) {
      // userAccelerometerEventStream already has gravity removed by
      // the OS — this magnitude reflects genuine motion, not tilt.
      final magnitude = event.x * event.x + event.y * event.y + event.z * event.z;
      _recentMagnitudes.add(magnitude);
      if (_recentMagnitudes.length > _windowSize) {
        _recentMagnitudes.removeAt(0);
      }
      if (_recentMagnitudes.length == _windowSize) {
        final mean =
            _recentMagnitudes.reduce((a, b) => a + b) / _windowSize;
        final variance = _recentMagnitudes
                .map((m) => (m - mean) * (m - mean))
                .reduce((a, b) => a + b) /
            _windowSize;
        _isStationary = variance < _stationaryVarianceThreshold;
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _recentMagnitudes.clear();
  }
}
