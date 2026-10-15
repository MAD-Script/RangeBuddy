import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/battery_state.dart';
import '../models/charge_session.dart';
import '../models/vehicle_profile.dart';

/// Explicit opt-in export. It contains calibration observations only and never
/// includes trips, GPS coordinates, saved places, or rider/passenger names.
class CalibrationExportService {
  Future<File> createBundle({
    required VehicleProfile profile,
    required String profileKey,
    required Box<BatteryState> states,
    required Box<ChargeSession> sessions,
  }) async {
    final state = states.get(profileKey);
    final relevantSessions = sessions.values
        .where((session) => session.profileKey == profileKey)
        .map((session) => {
              'charger_wattage_estimate': session.hours <= 0
                  ? null
                  : session.recoveredWh / session.hours / .85,
              'hours': session.hours,
              'recovered_wh': session.recoveredWh,
              'timestamp_ms': session.timestampMs,
            })
        .toList();
    final payload = {
      'schema_version': 1,
      'profile': {
        'catalog_id': profile.catalogId,
        'make_model': profile.name,
        'verified': profile.isVerified,
        'system_voltage': profile.systemVoltage,
        'battery_ah': profile.batteryAh,
        'motor_watt_peak': profile.motorWattPeak,
        'vehicle_weight_kg': profile.vehicleWeightKg,
        'base_wh_per_km': profile.baseWhPerKm,
      },
      'battery_prediction': state == null
          ? null
          : {
              'remaining_wh': state.remainingWh,
              'confidence': state.confidence,
              'last_full_charge_ms': state.lastFullChargeMs,
            },
      'charge_observations': relevantSessions,
    };
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}rangebuddy_calibration.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }
}
