import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/trip_sample.dart';
import '../models/trip_metadata.dart';
import '../models/bar_drop_event.dart';
import '../models/vehicle_alert_event.dart';
import '../services/trip_foreground_task.dart';
import '../services/motion_detector.dart';

/// Thrown when location permission is denied — callers should catch
/// this specifically and show the user a clear message, not just fail
/// silently.
class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);
  @override
  String toString() => message;
}

/// Thrown when a bar-drop value doesn't make physical sense — e.g.
/// logging a HIGHER bar than the last one recorded this trip. The
/// bike's bars only count down between charges, so this is a hard
/// guard against mis-taps (this is exactly the bug that produced the
/// 4 -> 5 -> 4 -> 5 glitch in your first data collection run).
class InvalidBarDropException implements Exception {
  final String message;
  InvalidBarDropException(this.message);
  @override
  String toString() => message;
}

/// Called on every GPS sample while a trip is being logged.
/// - rawSpeedKmh: exactly what the GPS reported this instant
/// - smoothedSpeedKmh: exponential moving average — use THIS for the
///   physics engine, since raw GPS speed is noisy and drag scales with
///   speed cubed (small noise gets amplified a lot)
/// - dtSeconds: real time elapsed since the previous sample (GPS
///   updates aren't evenly spaced, so this is measured, not assumed)
typedef TripSampleCallback = void Function({
  required double rawSpeedKmh,
  required double smoothedSpeedKmh,
  required double dtSeconds,
  required double latitude,
  required double longitude,
});

/// Handles a single "data collection mode" trip: requests location
/// permission, logs raw GPS samples, records start/end metadata, feeds
/// smoothed speed to the live RangeEngine via callback, tracks bar
/// drops + dashboard alert events, and can export everything to CSV.
class TripLogger {
  final Box<TripSample> sampleBox;
  final Box<TripMetadata> metadataBox;
  final Box<BarDropEvent> barDropBox;
  final Box<VehicleAlertEvent> alertBox;

  StreamSubscription<Position>? _positionSub;
  String? _activeTripId;
  int? _lastTimestampMs;
  double? _smoothedSpeedKmh;
  TripSampleCallback? _onSample;
  int? _lastLoggedBarLevel; // null = still on the full/top bar (5)
  double _cumulativeDistanceKm = 0; // for the notification, independent of UI
  final MotionDetector _motionDetector = MotionDetector();

  static const double _smoothingAlpha = 0.3; // 0=fully smoothed, 1=raw

  /// Your F52 shows 5 solid bars when full. Only 4 down to 1 are
  /// loggable "drops" — reaching genuinely empty is represented by the
  /// separate criticalBlinkingRed alert, not a "bar 0" drop.
  static const int highestLoggableBar = 4;
  static const int lowestLoggableBar = 1;

  TripLogger({
    required this.sampleBox,
    required this.metadataBox,
    required this.barDropBox,
    required this.alertBox,
  });

  bool get isLogging => _activeTripId != null;

  /// The trip currently being logged, if any — used by the UI to
  /// detect "there's already a ride in progress" and offer to resume
  /// viewing it, rather than starting a second one.
  String? get activeTripId => _activeTripId;

  /// Reattaches a sample callback to an ALREADY-running trip, without
  /// restarting GPS logging or touching metadata. Use this when the
  /// user navigates back into an in-progress ride (e.g. from Home's
  /// "Active Ride" tile) — startTrip() would throw since a trip is
  /// already active, and it would also wrongly reset the metadata.
  void attachSampleCallback(TripSampleCallback? callback) {
    _onSample = callback;
  }

  /// The lowest bar level still valid to select next (strictly less
  /// than the last one logged, or highestLoggableBar if none yet).
  /// Use this to build the dialog options in your UI so it's
  /// impossible to pick an invalid value in the first place.
  List<int> get availableBarOptions {
    final ceiling = (_lastLoggedBarLevel ?? highestLoggableBar + 1) - 1;
    return [
      for (var b = ceiling; b >= lowestLoggableBar; b--) b,
    ];
  }

  /// Checks and requests location permission. Call this BEFORE
  /// startTrip() so you can show a clear message if it's denied,
  /// rather than having the trip silently fail to log anything.
  Future<bool> ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationPermissionDeniedException(
        'Location services are turned off on this device. Enable them '
        'in system settings before starting a ride.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationPermissionDeniedException(
        'Location permission was denied. This app cannot track your '
        'ride without it — please allow location access and try again.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedException(
        'Location permission is permanently denied. Open this app\'s '
        'settings on your phone and enable Location manually.',
      );
    }

    return true;
  }

  /// Starts logging a trip. Throws [LocationPermissionDeniedException]
  /// if permission isn't granted — catch this in your UI and show the
  /// message to the user rather than letting it crash silently.
  ///
  /// [onSample] is called on every GPS fix with smoothed speed and the
  /// real elapsed time since the last fix — wire this directly to
  /// RangeEngine.tick() in your screen so the live display updates
  /// from real GPS instead of a simulated loop.
  Future<void> startTrip({
    required String tripId,
    required double riderWeightKg,
    double passengerWeightKg = 0,
    ChargeStateType startChargeType = ChargeStateType.unknown,
    int? startBarLevel,
    TripSampleCallback? onSample,
  }) async {
    if (isLogging) {
      throw StateError('A trip is already being logged: $_activeTripId');
    }

    await ensureLocationPermission();

    await metadataBox.put(
      tripId,
      TripMetadata(
        tripId: tripId,
        startTimestampMs: DateTime.now().millisecondsSinceEpoch,
        riderWeightKg: riderWeightKg,
        passengerWeightKg: passengerWeightKg,
        startChargeType: startChargeType,
        startBarLevel: startBarLevel,
      ),
    );

    _activeTripId = tripId;
    _lastTimestampMs = null;
    _smoothedSpeedKmh = null;
    _lastLoggedBarLevel = null;
    _cumulativeDistanceKm = 0;
    _onSample = onSample;

    await startTripForegroundService();
    _motionDetector.start();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // we want time-based samples, not distance-based
    );

    _positionSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) => _onPosition(tripId, position),
    );
  }

  void _onPosition(String tripId, Position position) {
    // Filter out obviously bad fixes — anything worse than ~20m
    // accuracy will pollute speed/altitude derived stats badly.
    if (position.accuracy > 20) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rawSpeedKmh = position.speed * 3.6; // Geolocator gives m/s

    // ZUPT correction: if the accelerometer confidently says we're not
    // moving in ANY direction, trust that over GPS's noisy near-zero
    // speed reading (GPS drift can show 3-5km/h "creep" while parked).
    // The raw sample stored to Hive keeps the true GPS value regardless
    // — this correction only affects the live engine/UI/smoothing path.
    final stationaryOverride =
        _motionDetector.hasEnoughData && _motionDetector.isStationary;
    final effectiveSpeedKmh = stationaryOverride ? 0.0 : rawSpeedKmh;

    // Exponential moving average smoothing — see typedef doc above
    // for why this matters (drag scales with speed^3).
    _smoothedSpeedKmh = _smoothedSpeedKmh == null
        ? effectiveSpeedKmh
        : (_smoothingAlpha * effectiveSpeedKmh) +
            ((1 - _smoothingAlpha) * _smoothedSpeedKmh!);

    final dtSeconds =
        _lastTimestampMs == null ? 1.0 : (nowMs - _lastTimestampMs!) / 1000.0;
    _lastTimestampMs = nowMs;
    _cumulativeDistanceKm += effectiveSpeedKmh * (dtSeconds / 3600.0);
    updateTripForegroundNotification(
      distanceKm: _cumulativeDistanceKm,
      speedKmh: effectiveSpeedKmh,
    );

    sampleBox.add(
      TripSample(
        tripId: tripId,
        timestampMs: nowMs,
        latitude: position.latitude,
        longitude: position.longitude,
        gpsSpeedKmh: rawSpeedKmh, // true raw GPS value, uncorrected
        altitudeM: position.altitude,
        accuracyM: position.accuracy,
      ),
    );

    _onSample?.call(
      rawSpeedKmh: effectiveSpeedKmh,
      smoothedSpeedKmh: _smoothedSpeedKmh!,
      dtSeconds: dtSeconds,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Call this the moment you notice the dashboard bar just dropped.
  /// Enforces that the new level is lower than the last one logged
  /// this trip, and within the 4-1 loggable range — this is the fix
  /// for the 4 -> 5 -> 4 -> 5 glitch from mis-taps.
  Future<void> logBarDropEvent(int barLevelAfterDrop) async {
    if (!isLogging) {
      throw StateError('No active trip — start a trip before logging events.');
    }
    if (barLevelAfterDrop > highestLoggableBar ||
        barLevelAfterDrop < lowestLoggableBar) {
      throw InvalidBarDropException(
        'Bar level must be between $lowestLoggableBar and '
        '$highestLoggableBar.',
      );
    }
    final ceiling = _lastLoggedBarLevel ?? (highestLoggableBar + 1);
    if (barLevelAfterDrop >= ceiling) {
      throw InvalidBarDropException(
        'Bar $barLevelAfterDrop is not lower than the last logged bar '
        '($_lastLoggedBarLevel) — bars only count down between charges.',
      );
    }

    await barDropBox.add(
      BarDropEvent(
        tripId: _activeTripId!,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        barLevelAfterDrop: barLevelAfterDrop,
      ),
    );
    _lastLoggedBarLevel = barLevelAfterDrop;
  }

  /// Call this when you notice one of the dashboard's low-charge
  /// warnings — the audible alert, the refuel indicator lighting up,
  /// or the last bar starting to blink red. Each is a useful anchor
  /// for pinning down the discharge curve near empty.
  Future<void> logAlertEvent(VehicleAlertType alertType) async {
    if (!isLogging) {
      throw StateError('No active trip — start a trip before logging events.');
    }
    await alertBox.add(
      VehicleAlertEvent(
        tripId: _activeTripId!,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        alertType: alertType,
      ),
    );
  }

  Future<void> stopTrip({
    ChargeStateType endChargeType = ChargeStateType.unknown,
    int? endBarLevel,
    String notes = '',
  }) async {
    if (!isLogging) return;
    await _positionSub?.cancel();
    _positionSub = null;
    _onSample = null;
    await stopTripForegroundService();
    _motionDetector.stop();

    final tripId = _activeTripId!;
    final meta = metadataBox.get(tripId);
    if (meta != null) {
      meta.endTimestampMs = DateTime.now().millisecondsSinceEpoch;
      meta.endChargeType = endChargeType;
      meta.endBarLevel = endBarLevel;
      meta.notes = notes;
      await meta.save();
    }
    _activeTripId = null;
  }

  /// Exports one trip as two files: `{tripId}_samples.csv` (the raw
  /// time-series GPS data — genuinely tabular, CSV is the right shape
  /// for it) and `{tripId}_trip.json` (metadata + bar-drop events +
  /// alert events combined — these are a record with nested lists,
  /// which fits JSON far better than forcing them into flat CSVs with
  /// mismatched schemas). Returns the file paths for sharing.
  Future<List<File>> exportTrip(String tripId) async {
    final dir = await getApplicationDocumentsDirectory();

    final samples = sampleBox.values.where((s) => s.tripId == tripId).toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    final samplesCsv = StringBuffer()
      ..writeln('timestamp_ms,latitude,longitude,speed_kmh,altitude_m,accuracy_m');
    for (final s in samples) {
      samplesCsv.writeln(
        '${s.timestampMs},${s.latitude},${s.longitude},'
        '${s.gpsSpeedKmh},${s.altitudeM ?? ""},${s.accuracyM}',
      );
    }
    final samplesFile = File('${dir.path}/${tripId}_samples.csv');
    await samplesFile.writeAsString(samplesCsv.toString());

    final meta = metadataBox.get(tripId);
    final barDrops = barDropBox.values.where((b) => b.tripId == tripId).toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final alerts = alertBox.values.where((a) => a.tripId == tripId).toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    final tripJson = <String, dynamic>{
      'trip_id': tripId,
      'start_ts_ms': meta?.startTimestampMs,
      'end_ts_ms': meta?.endTimestampMs,
      'rider_kg': meta?.riderWeightKg,
      'passenger_kg': meta?.passengerWeightKg,
      'start_charge_type': meta?.startChargeType.name,
      'start_bar': meta?.startBarLevel,
      'end_charge_type': meta?.endChargeType.name,
      'end_bar': meta?.endBarLevel,
      'notes': meta?.notes ?? '',
      'bar_drop_events': [
        for (final b in barDrops)
          {'timestamp_ms': b.timestampMs, 'bar_level_after_drop': b.barLevelAfterDrop},
      ],
      'alert_events': [
        for (final a in alerts)
          {'timestamp_ms': a.timestampMs, 'alert_type': a.alertType.name},
      ],
    };
    final tripJsonFile = File('${dir.path}/${tripId}_trip.json');
    await tripJsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(tripJson));

    return [samplesFile, tripJsonFile];
  }
}
