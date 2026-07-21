import 'package:hive/hive.dart';

part 'passenger.g.dart';

/// A saved passenger you regularly ride with — lets you pick their
/// weight before a ride instead of retyping it every time. Only one
/// passenger can be active per ride (the bike seats 2 total), which is
/// enforced in the UI, not here.
@HiveType(typeId: 7)
class Passenger extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double weightKg;

  Passenger({required this.name, required this.weightKg});
}
