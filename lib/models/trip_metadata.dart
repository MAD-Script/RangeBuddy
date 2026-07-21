import 'package:hive/hive.dart';

part 'trip_metadata.g.dart';

/// Charge state at the start or end of a trip. This is your ONLY
/// ground-truth signal — the bike has no percentage readout, so
/// "fullCharge" and "barLevel" are the two anchor types you can
/// actually observe.
@HiveType(typeId: 2)
enum ChargeStateType {
  @HiveField(0)
  fullCharge,
  @HiveField(1)
  barLevel,
  @HiveField(2)
  unknown,
}

@HiveType(typeId: 3)
class TripMetadata extends HiveObject {
  @HiveField(0)
  String tripId;

  @HiveField(1)
  int startTimestampMs;

  @HiveField(2)
  int? endTimestampMs;

  @HiveField(3)
  double riderWeightKg;

  @HiveField(4)
  double passengerWeightKg;

  @HiveField(5)
  ChargeStateType startChargeType;

  @HiveField(6)
  int? startBarLevel; // 1-6, only meaningful if startChargeType == barLevel

  @HiveField(7)
  ChargeStateType endChargeType;

  @HiveField(8)
  int? endBarLevel;

  @HiveField(9)
  String notes; // e.g. "AC blasting", "carried groceries", "heavy rain"

  TripMetadata({
    required this.tripId,
    required this.startTimestampMs,
    required this.riderWeightKg,
    this.passengerWeightKg = 0,
    this.startChargeType = ChargeStateType.unknown,
    this.startBarLevel,
    this.endTimestampMs,
    this.endChargeType = ChargeStateType.unknown,
    this.endBarLevel,
    this.notes = '',
  });
}
