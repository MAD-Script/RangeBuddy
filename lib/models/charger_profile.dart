import 'package:hive/hive.dart';

part 'charger_profile.g.dart';

@HiveType(typeId: 9)
class ChargerProfile extends HiveObject {
  @HiveField(0)
  String profileKey;
  @HiveField(1)
  String name;
  @HiveField(2)
  double wattage;
  @HiveField(3)
  double efficiency;
  @HiveField(4)
  bool isDefault;

  ChargerProfile({required this.profileKey, required this.name, required this.wattage, this.efficiency = .85, this.isDefault = false});
}
