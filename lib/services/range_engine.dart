import 'dart:math';
import '../models/vehicle_profile.dart';

/// Pure Dart range/battery estimation engine.
/// No Flutter or Hive dependency here on purpose — keeps this class
/// trivially unit-testable against your known real-world benchmarks.
class RangeEngine {
  final VehicleProfile profile;
  double eRemainingWh;

  static const double _gravity = 9.81;
  static const double _airDensity = 1.2; // kg/m^3

  RangeEngine({required this.profile, double? startingWh})
      : eRemainingWh = startingWh ?? profile.totalEnergyWh();

  /// Steady-state cruise power demand in Watts (rolling resistance +
  /// aerodynamic drag) at a given speed and total system mass.
  /// totalMassKg should be vehicleWeightKg + rider + passenger — NOT
  /// rider weight alone.
  double cruisePowerDemandWatts({
    required double speedKmh,
    required double totalMassKg,
  }) {
    final v = speedKmh / 3.6; // convert to m/s
    final rolling = profile.crr * totalMassKg * _gravity * v;
    final drag = 0.5 * _airDensity * profile.dragCoefficientArea * pow(v, 3);
    return (rolling + drag) / profile.efficiency;
  }

  /// Extra Wh consumed in this tick due to stop-and-go congestion,
  /// on top of the steady-state cruise prediction. Only applies below
  /// congestionSpeedThresholdKmh, and only while actually moving
  /// (a full stop at a light shouldn't itself burn "distance-based"
  /// overhead — that's handled separately by idle/vampire drain, not
  /// modeled yet).
  double _congestionOverheadWh({
    required double smoothedSpeedKmh,
    required double dtSeconds,
  }) {
    if (smoothedSpeedKmh <= 0 ||
        smoothedSpeedKmh >= profile.congestionSpeedThresholdKmh) {
      return 0;
    }
    final kmTraveledThisTick = smoothedSpeedKmh * (dtSeconds / 3600.0);
    return profile.congestionOverheadWhPerKm * kmTraveledThisTick;
  }

  /// Call once per second (or per GPS sample) while a trip is active.
  /// Use smoothed speed (moving average), not raw GPS speed — drag
  /// scales with speed^3 so raw GPS jitter gets amplified badly.
  void tick({
    required double smoothedSpeedKmh,
    required double totalMassKg,
    required double dtSeconds,
  }) {
    final cruiseWatts = cruisePowerDemandWatts(
      speedKmh: smoothedSpeedKmh,
      totalMassKg: totalMassKg,
    );
    final cruiseWhConsumed = cruiseWatts * (dtSeconds / 3600.0);
    final congestionWh = _congestionOverheadWh(
      smoothedSpeedKmh: smoothedSpeedKmh,
      dtSeconds: dtSeconds,
    );
    final totalWhConsumed = cruiseWhConsumed + congestionWh;
    eRemainingWh =
        (eRemainingWh - totalWhConsumed).clamp(0, profile.totalEnergyWh());
  }

  double batteryPercent() =>
      (eRemainingWh / profile.totalEnergyWh()) * 100;

  /// Rough range remaining using the profile's fixed baseline Wh/km.
  /// This is the "sanity check" number — the live tick() model above is
  /// what should drive the primary display, since it responds to your
  /// actual current speed rather than an average.
  double estimatedRangeKmBaseline() =>
      eRemainingWh / profile.baseWhPerKm;

  /// Calibration trigger #1: user confirms bike is fully charged.
  void resetToFull() {
    eRemainingWh = profile.totalEnergyWh();
  }

  /// Calibration trigger #2: user taps "first bar just dropped" at a
  /// known distance. Compares what the physics model calculated against
  /// what your bike's own dashboard is telling you, and nudges the
  /// virtual tank to match.
  void recalibrateAgainstAnchor({
    required double whConsumedAccordingToModel,
    required double expectedWhConsumedAtAnchor,
  }) {
    final drift = whConsumedAccordingToModel - expectedWhConsumedAtAnchor;
    eRemainingWh = (eRemainingWh - drift)
        .clamp(0, profile.totalEnergyWh());
  }

  /// Calibration trigger #3: emergency/partial charge session.
  void addChargedEnergy({
    required double chargerWattage,
    required double hoursCharged,
    double chargingEfficiency = 0.85,
  }) {
    final added = chargerWattage * hoursCharged * chargingEfficiency;
    eRemainingWh =
        (eRemainingWh + added).clamp(0, profile.totalEnergyWh());
  }
}