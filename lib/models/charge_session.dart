import 'package:hive/hive.dart';

part 'charge_session.g.dart';

@HiveType(typeId: 10)
class ChargeSession extends HiveObject {
  @HiveField(0) String profileKey;
  @HiveField(1) String chargerName;
  @HiveField(2) double hours;
  @HiveField(3) double recoveredWh;
  @HiveField(4) int timestampMs;
  @HiveField(5) String? placeName;
  ChargeSession({required this.profileKey, required this.chargerName, required this.hours, required this.recoveredWh, required this.timestampMs, this.placeName});
}
