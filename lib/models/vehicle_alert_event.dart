import 'package:hive/hive.dart';

part 'vehicle_alert_event.g.dart';

/// The dashboard/bike-generated warnings you can notice and log mid-ride,
/// separate from bar drops. These are extra calibration anchors —
/// each one happens at a roughly consistent point in the discharge
/// curve, so logging them across many trips helps pin down the curve
/// near empty, where graphene batteries fall off fast.
@HiveType(typeId: 5)
enum VehicleAlertType {
  @HiveField(0)
  lowBatteryAudibleWarning, // bike beeps to warn charge is getting low

  @HiveField(1)
  refuelIndicatorOn, // the refuel/charge icon lights up on the dash

  @HiveField(2)
  criticalBlinkingRed, // last bar blinking red — critically low
}

@HiveType(typeId: 6)
class VehicleAlertEvent extends HiveObject {
  @HiveField(0)
  String tripId;

  @HiveField(1)
  int timestampMs;

  @HiveField(2)
  VehicleAlertType alertType;

  VehicleAlertEvent({
    required this.tripId,
    required this.timestampMs,
    required this.alertType,
  });
}
