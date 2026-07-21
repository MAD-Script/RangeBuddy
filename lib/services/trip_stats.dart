import '../models/trip_sample.dart';

/// Computed stats for a completed trip, derived from its raw samples.
/// Mirrors the feature computation in analysis/analyze_trips.py so the
/// in-app trip detail view and the offline analysis agree with each
/// other on what these numbers mean.
class TripStats {
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int stopCount;
  final double elevationGainM;
  final Duration duration;

  const TripStats({
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.stopCount,
    required this.elevationGainM,
    required this.duration,
  });

  static const _stoppedThresholdKmh = 2.0;
  static const _gpsGapSkipSeconds = 30;

  factory TripStats.fromSamples(List<TripSample> samples) {
    if (samples.isEmpty) {
      return const TripStats(
        distanceKm: 0,
        avgSpeedKmh: 0,
        maxSpeedKmh: 0,
        stopCount: 0,
        elevationGainM: 0,
        duration: Duration.zero,
      );
    }

    final sorted = [...samples]
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    var distanceKm = 0.0;
    var elevationGain = 0.0;
    var stopCount = 0;
    var wasStopped = true;
    var maxSpeed = 0.0;
    var speedSum = 0.0;

    for (var i = 0; i < sorted.length; i++) {
      final speed = sorted[i].gpsSpeedKmh;
      speedSum += speed;
      if (speed > maxSpeed) maxSpeed = speed;

      if (i > 0) {
        final dtSeconds =
            (sorted[i].timestampMs - sorted[i - 1].timestampMs) / 1000.0;
        if (dtSeconds > 0 && dtSeconds <= _gpsGapSkipSeconds) {
          distanceKm += speed * (dtSeconds / 3600.0);

          final altNow = sorted[i].altitudeM;
          final altPrev = sorted[i - 1].altitudeM;
          if (altNow != null && altPrev != null && altNow > altPrev) {
            elevationGain += altNow - altPrev;
          }
        }
      }

      final isStopped = speed < _stoppedThresholdKmh;
      if (isStopped && !wasStopped) stopCount++;
      wasStopped = isStopped;
    }

    return TripStats(
      distanceKm: distanceKm,
      avgSpeedKmh: speedSum / sorted.length,
      maxSpeedKmh: maxSpeed,
      stopCount: stopCount,
      elevationGainM: elevationGain,
      duration: Duration(
        milliseconds: sorted.last.timestampMs - sorted.first.timestampMs,
      ),
    );
  }
}
