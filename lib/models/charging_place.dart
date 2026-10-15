import 'package:hive/hive.dart';

part 'charging_place.g.dart';

@HiveType(typeId: 11)
class ChargingPlace extends HiveObject {
  @HiveField(0) String profileKey;
  @HiveField(1) String name;
  @HiveField(2) double latitude;
  @HiveField(3) double longitude;
  @HiveField(4) bool isFree;
  @HiveField(5) String? chargerName;
  ChargingPlace({required this.profileKey, required this.name, required this.latitude, required this.longitude, required this.isFree, this.chargerName});
}
