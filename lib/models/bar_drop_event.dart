import 'package:hive/hive.dart';

part 'bar_drop_event.g.dart';

/// A mid-trip event: the dashboard's battery bar just dropped from one
/// segment to the next. These are your real calibration anchors — far
/// more valuable than start/end state alone, since they let you tie a
/// specific cumulative distance/physics-predicted-energy to a specific
/// bar transition, across many trips.
@HiveType(typeId: 4)
class BarDropEvent extends HiveObject {
  @HiveField(0)
  String tripId;

  @HiveField(1)
  int timestampMs;

  @HiveField(2)
  int barLevelAfterDrop; // e.g. 5 if it just dropped from 6 to 5

  BarDropEvent({
    required this.tripId,
    required this.timestampMs,
    required this.barLevelAfterDrop,
  });
}
