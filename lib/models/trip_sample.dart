import 'package:hive/hive.dart';

part 'trip_sample.g.dart';

/// One raw GPS sample, logged roughly once per second while a
/// data-collection trip is active. Kept deliberately dumb/raw here —
/// all the derived stats (stop count, elevation gain, avg speed) get
/// computed later during analysis, not on-device in real time.
@HiveType(typeId: 1)
class TripSample extends HiveObject {
  @HiveField(0)
  String tripId;

  @HiveField(1)
  int timestampMs; // DateTime.now().millisecondsSinceEpoch

  @HiveField(2)
  double latitude;

  @HiveField(3)
  double longitude;

  @HiveField(4)
  double gpsSpeedKmh;

  @HiveField(5)
  double? altitudeM; // nullable — not all devices/fixes give altitude

  @HiveField(6)
  double accuracyM; // GPS horizontal accuracy, for filtering bad fixes

  TripSample({
    required this.tripId,
    required this.timestampMs,
    required this.latitude,
    required this.longitude,
    required this.gpsSpeedKmh,
    required this.accuracyM,
    this.altitudeM,
  });
}
