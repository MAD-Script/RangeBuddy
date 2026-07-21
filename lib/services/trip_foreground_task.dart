import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// The persistent notification shown while a ride is being tracked —
/// this is what keeps Android from killing GPS tracking once the app
/// is backgrounded. Must be initialized once at app startup
/// (see main.dart), then started/stopped by TripLogger per ride.

/// Top-level entry point required by flutter_foreground_task — this
/// runs in a separate isolate, which is why it can't be a class method
/// or closure.
@pragma('vm:entry-point')
void tripForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TripTaskHandler());
}

class _TripTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: TripLogger updates the notification text directly via
    // FlutterForegroundTask.updateService() as distance/speed change,
    // rather than this isolate re-computing anything on its own timer.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Call once at app startup, before any trip starts.
void initTripForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'ev_range_tracker_trip',
      channelName: 'Active Ride Tracking',
      channelDescription:
          'Shows while a ride is being tracked, so GPS keeps running in the background.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
}

/// Android 13+ requires this permission to be granted before a
/// foreground service notification will actually show. Call this
/// before startTripForegroundService().
Future<void> ensureNotificationPermission() async {
  final permission = await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
}

Future<void> startTripForegroundService() async {
  await ensureNotificationPermission();
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.restartService();
    return;
  }
  await FlutterForegroundTask.startService(
    serviceId: 1001,
    notificationTitle: 'Ride in progress',
    notificationText: 'Tracking your ride — tap to return to the app',
    callback: tripForegroundTaskCallback,
  );
}

/// Call as often as you like (e.g. every GPS sample) — updateService
/// just replaces the notification's text, it's cheap.
void updateTripForegroundNotification({
  required double distanceKm,
  required double speedKmh,
}) {
  FlutterForegroundTask.updateService(
    notificationTitle: 'Ride in progress',
    notificationText:
        '${distanceKm.toStringAsFixed(1)} km · ${speedKmh.toStringAsFixed(0)} km/h',
  );
}

Future<void> stopTripForegroundService() async {
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}
