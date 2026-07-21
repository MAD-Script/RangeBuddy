import 'package:flutter_test/flutter_test.dart';
import 'package:ev_range_tracker/models/vehicle_profile.dart';
import 'package:ev_range_tracker/services/range_engine.dart';

void main() {
  group('RangeEngine physics model', () {
    test('total energy capacity matches spec (72V x 23Ah = 1656Wh)', () {
      final profile = VehicleProfile();
      expect(profile.totalEnergyWh(), closeTo(1656.0, 0.5));
    });

    test(
        'cruise-only physics undershoots real consumption in heavy '
        'traffic — this is expected, congestion overhead exists to '
        'cover exactly this gap rather than distorting drag/mass', () {
      final profile = VehicleProfile();
      final engine = RangeEngine(profile: profile);

      // Your actual commute: Mirpur DOHS -> Tongi College Gate,
      // ~12.5km in ~37.5min, avg 20km/h, heavy stop-and-go.
      const commuteSpeedKmh = 20.0;
      final totalMassKg = profile.vehicleWeightKg + profile.defaultRiderWeightKg; // 172kg

      final cruiseWatts = engine.cruisePowerDemandWatts(
        speedKmh: commuteSpeedKmh,
        totalMassKg: totalMassKg,
      );
      final cruiseOnlyWhPerKm = cruiseWatts / commuteSpeedKmh;

      // ~11.9 Wh/km from physics alone — well under your real 18.4,
      // confirming stop-and-go congestion isn't captured by cruise
      // physics and needs its own term.
      expect(cruiseOnlyWhPerKm, lessThan(profile.baseWhPerKm));
    });

    test(
        'full model (cruise physics + congestion overhead) matches '
        'your real commute benchmark of 18.4 Wh/km', () {
      final profile = VehicleProfile(); // congestionOverheadWhPerKm = 6.5
      final engine = RangeEngine(profile: profile);

      const commuteSpeedKmh = 20.0;
      const commuteDistanceKm = 12.5;
      final totalMassKg =
          profile.vehicleWeightKg + profile.defaultRiderWeightKg;

      final startingWh = engine.eRemainingWh;
      var traveledKm = 0.0;
      while (traveledKm < commuteDistanceKm) {
        engine.tick(
          smoothedSpeedKmh: commuteSpeedKmh,
          totalMassKg: totalMassKg,
          dtSeconds: 1,
        );
        traveledKm += commuteSpeedKmh * (1 / 3600.0);
      }

      final consumedWh = startingWh - engine.eRemainingWh;
      final actualWhPerKm = consumedWh / traveledKm;

      // Should land very close to your real 18.4 Wh/km benchmark.
      expect(actualWhPerKm, closeTo(profile.baseWhPerKm, 0.5));
    });

    test('resetToFull() calibration trigger works', () {
      final profile = VehicleProfile();
      final engine = RangeEngine(profile: profile, startingWh: 200);
      engine.resetToFull();
      expect(engine.batteryPercent(), closeTo(100.0, 0.01));
    });

    test('addChargedEnergy() adds expected Wh for an emergency charge', () {
      final profile = VehicleProfile();
      final engine = RangeEngine(profile: profile, startingWh: 0);
      // e.g. 300W charger for 1 hour at 85% efficiency
      engine.addChargedEnergy(chargerWattage: 300, hoursCharged: 1);
      expect(engine.eRemainingWh, closeTo(255.0, 0.5));
    });
  });
}