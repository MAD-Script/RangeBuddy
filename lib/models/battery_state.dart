import 'package:hive/hive.dart';

part 'battery_state.g.dart';

/// Persisted virtual-battery snapshot for one selected bike profile.
@HiveType(typeId: 8)
class BatteryState extends HiveObject {
  @HiveField(0)
  String profileKey;
  @HiveField(1)
  double remainingWh;
  @HiveField(2)
  int lastUpdatedMs;
  @HiveField(3)
  int? lastFullChargeMs;
  @HiveField(4)
  double confidence;

  BatteryState({
    required this.profileKey,
    required this.remainingWh,
    required this.lastUpdatedMs,
    this.lastFullChargeMs,
    this.confidence = .45,
  });
}
