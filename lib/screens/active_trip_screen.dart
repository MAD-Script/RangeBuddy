import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip_metadata.dart';
import '../models/trip_sample.dart';
import '../models/vehicle_alert_event.dart';
import '../models/charging_place.dart';
import '../services/range_engine.dart';
import '../services/trip_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/segmented_bar.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/trip_route_map.dart';

class ActiveTripScreen extends StatefulWidget {
  final RangeEngine engine;
  final TripLogger logger;
  final String tripId;
  final double riderWeightKg;
  final double passengerWeightKg;
  final double totalMassKg;
  final Directory tileCacheDir;
  final Box<TripMetadata> metadataBox;
  final VoidCallback? onBatteryChanged;
  final Box<ChargingPlace>? chargingPlaceBox;
  final String? profileKey;
  final bool isCalibrationRide;

  const ActiveTripScreen({
    super.key,
    required this.engine,
    required this.logger,
    required this.tripId,
    required this.riderWeightKg,
    required this.totalMassKg,
    required this.tileCacheDir,
    required this.metadataBox,
    this.onBatteryChanged,
    this.chargingPlaceBox,
    this.profileKey,
    this.isCalibrationRide = false,
    this.passengerWeightKg = 0,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  DateTime? _tripStartTime;
  Duration _elapsed = Duration.zero;
  double _distanceKm = 0;
  double _rawSpeedKmh = 0;
  Timer? _clockTimer;
  bool _starting = true;
  String? _errorMessage;
  final List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    // Going back no longer ends the ride (see dispose() below) — so
    // opening this screen can mean either starting a fresh trip, or
    // resuming one that's already running in the background via
    // Home's "Active Ride" tile. Each needs different setup.
    if (widget.logger.isLogging && widget.logger.activeTripId == widget.tripId) {
      _resumeExistingTrip();
    } else {
      _startNewTrip();
    }
  }

  Future<void> _startNewTrip() async {
    try {
      await widget.logger.startTrip(
        tripId: widget.tripId,
        riderWeightKg: widget.riderWeightKg,
        passengerWeightKg: widget.passengerWeightKg,
        isCalibrationRide: widget.isCalibrationRide,
        onSample: _onSample,
      );
      _tripStartTime = DateTime.now();
      _startClock();
      setState(() => _starting = false);
    } on LocationPermissionDeniedException catch (e) {
      setState(() {
        _starting = false;
        _errorMessage = e.message;
      });
    }
  }

  // Rebuilds this screen's local UI state (route, distance, elapsed
  // time) from what TripLogger has already persisted while this
  // screen was off-screen — the trip itself never stopped, only the
  // widget showing it was gone.
  void _resumeExistingTrip() {
    final meta = widget.metadataBox.get(widget.tripId);
    _tripStartTime = meta != null
        ? DateTime.fromMillisecondsSinceEpoch(meta.startTimestampMs)
        : DateTime.now();

    final pastSamples = widget.logger.sampleBox.values
        .where((s) => s.tripId == widget.tripId)
        .toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    var distanceKm = 0.0;
    for (var i = 0; i < pastSamples.length; i++) {
      final s = pastSamples[i];
      _routePoints.add(LatLng(s.latitude, s.longitude));
      if (i > 0) {
        final dtSeconds =
            (s.timestampMs - pastSamples[i - 1].timestampMs) / 1000.0;
        if (dtSeconds > 0 && dtSeconds <= 30) {
          distanceKm += s.gpsSpeedKmh * (dtSeconds / 3600.0);
        }
      }
    }
    _distanceKm = distanceKm;
    if (pastSamples.isNotEmpty) _rawSpeedKmh = pastSamples.last.gpsSpeedKmh;

    widget.logger.attachSampleCallback(_onSample);
    _startClock();
    setState(() => _starting = false);
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tripStartTime != null) {
        setState(() => _elapsed = DateTime.now().difference(_tripStartTime!));
      }
    });
  }

  // Real GPS -> engine wiring: every position update from TripLogger
  // flows straight into RangeEngine.tick(), using smoothed speed (not
  // raw) since drag scales with speed^3 and raw GPS speed is noisy
  // enough to make that swing wildly tick to tick.
  void _onSample({
    required double rawSpeedKmh,
    required double smoothedSpeedKmh,
    required double dtSeconds,
    required double latitude,
    required double longitude,
  }) {
    widget.engine.tick(
      smoothedSpeedKmh: smoothedSpeedKmh,
      totalMassKg: widget.totalMassKg,
      dtSeconds: dtSeconds,
    );
    widget.onBatteryChanged?.call();
    _distanceKm += rawSpeedKmh * (dtSeconds / 3600.0);
    if (mounted) {
      setState(() {
        _rawSpeedKmh = rawSpeedKmh;
        _routePoints.add(LatLng(latitude, longitude));
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    // Deliberately NOT stopping the trip here. Leaving this screen —
    // including via the back button — should just navigate away while
    // the ride keeps recording in the background (the persistent
    // notification is what keeps GPS alive). Only "End Ride" stops it.
    // Detach the callback so a disposed screen doesn't get setState
    // called on it, but the trip itself carries on.
    if (widget.logger.isLogging && widget.logger.activeTripId == widget.tripId) {
      widget.logger.attachSampleCallback(null);
    }
    super.dispose();
  }

  Future<void> _promptBarDrop() async {
    final options = widget.logger.availableBarOptions;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Already at the lowest loggable bar — use "Log Alert" for '
            'the critical blinking-red warning instead.',
          ),
        ),
      );
      return;
    }

    final level = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Which bar just dropped to?'),
        children: [
          for (final n in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, n),
              child: Text('Bar $n'),
            ),
        ],
      ),
    );
    if (level == null) return;

    try {
      await widget.logger.logBarDropEvent(level);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged: bar dropped to $level')),
        );
        setState(() {}); // refresh availableBarOptions for next tap
      }
    } on InvalidBarDropException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _promptAlertEvent() async {
    const labels = {
      VehicleAlertType.lowBatteryAudibleWarning: 'Low-battery audible warning',
      VehicleAlertType.refuelIndicatorOn: 'Refuel indicator turned on',
      VehicleAlertType.criticalBlinkingRed: 'Last bar blinking red (critical)',
    };

    final chosen = await showDialog<VehicleAlertType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Which warning just happened?'),
        children: [
          for (final entry in labels.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (chosen == null) return;

    await widget.logger.logAlertEvent(chosen);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged: ${labels[chosen]}')),
      );
    }
  }

  Future<void> _logCalibrationEvent(
      VehicleAlertType type, String label) async {
    await widget.logger.logAlertEvent(type);
    if (type == VehicleAlertType.batteryDrained) {
      widget.engine.eRemainingWh = 0;
      widget.onBatteryChanged?.call();
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logged: $label')));
    }
  }

  Future<void> _endRide() async {
    await widget.logger.stopTrip();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }

  _Reachability? _nearestReachablePlace(double rangeKm) {
    if (_routePoints.isEmpty ||
        widget.chargingPlaceBox == null ||
        widget.profileKey == null) {
      return null;
    }
    final current = _routePoints.last;
    final distance = const Distance();
    final candidates = widget.chargingPlaceBox!.values
        .where((place) => place.profileKey == widget.profileKey)
        .map((place) {
      final directKm = distance.as(
        LengthUnit.Kilometer,
        current,
        LatLng(place.latitude, place.longitude),
      );
      return _Reachability(place, directKm * 1.35 + 5);
    }).toList()
      ..sort((a, b) => a.requiredRangeKm.compareTo(b.requiredRangeKm));
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Ride')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final engine = widget.engine;
    final batteryPercent = engine.batteryPercent();
    final rangeKm = engine.estimatedRangeKmBaseline();
    final maxRangeKm =
        engine.profile.totalEnergyWh() / engine.profile.baseWhPerKm;
    final nearestPlace = _nearestReachablePlace(rangeKm);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.isCalibrationRide ? const Color(0xFFFFC107) : null,
        title: const Text('Ride in progress', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.gps_fixed_rounded, color: Color(0xFF35A982)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isCalibrationRide)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
                  child: const Text('CALIBRATION RIDE · Do not log charging until Battery drained is recorded.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              Center(
                child: SpeedGauge(
                  speedKmh: _rawSpeedKmh,
                  maxSpeedKmh: 60,
                ),
              ),
              Text(
                'ECO 0–40  ·  CITY 0–45  ·  SPORT 0–55  ·  RED ABOVE 55',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              if (nearestPlace != null)
                Card(
                  color: rangeKm >= nearestPlace.requiredRangeKm
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(
                      rangeKm >= nearestPlace.requiredRangeKm
                          ? Icons.location_on_rounded
                          : Icons.warning_amber_rounded,
                    ),
                    title: Text(
                      rangeKm >= nearestPlace.requiredRangeKm
                          ? '${nearestPlace.place.name} is safely reachable'
                          : '${nearestPlace.place.name} is not safely reachable',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Needs ~${nearestPlace.requiredRangeKm.toStringAsFixed(0)} km including route and reserve buffer.',
                    ),
                  ),
                ),
              if (nearestPlace == null && _routePoints.isNotEmpty)
                const _NoSavedPlaceNotice(),
              if (nearestPlace != null || _routePoints.isNotEmpty)
                const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _RideMetric(
                    label: 'Distance',
                    value: '${_distanceKm.toStringAsFixed(1)} km',
                    icon: Icons.route,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _RideMetric(
                    label: 'Elapsed',
                    value: _formatDuration(_elapsed),
                    icon: Icons.timer_outlined,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: TripRouteMap(
                        routePoints: _routePoints,
                        currentPosition: _routePoints.isNotEmpty ? _routePoints.last : null,
                        tileCacheDir: widget.tileCacheDir,
                        interactive: false,
                        followCurrentPosition: true,
                        savedPlaces: widget.chargingPlaceBox?.values
                            .where((place) => place.profileKey == widget.profileKey)
                            .map((place) => LatLng(place.latitude, place.longitude))
                            .toList() ?? const [],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SegmentedBar(
                          label: 'Charge Left',
                          valueLabel: '${batteryPercent.toStringAsFixed(0)}%',
                          fraction: batteryPercent / 100,
                          color: const Color(0xFF39A875),
                          icon: Icons.battery_charging_full,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 92,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: SegmentedBar(
                          label: 'Range Left',
                          valueLabel: '${rangeKm.toStringAsFixed(0)} km',
                          fraction: maxRangeKm > 0 ? rangeKm / maxRangeKm : 0,
                          color: const Color(0xFF2196F3),
                          icon: Icons.route_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.isCalibrationRide) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _logCalibrationEvent(VehicleAlertType.lowBatteryAudibleWarning, 'Audible warning'), icon: const Icon(Icons.volume_up_outlined), label: const Text('Audible warning'))),
                    const SizedBox(width: 6),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _logCalibrationEvent(VehicleAlertType.criticalBlinkingRed, 'Critical warning'), icon: const Icon(Icons.warning_amber_rounded), label: const Text('Critical'))),
                    const SizedBox(width: 6),
                    Expanded(child: FilledButton.icon(onPressed: () => _logCalibrationEvent(VehicleAlertType.batteryDrained, 'Battery drained'), icon: const Icon(Icons.battery_0_bar_rounded), label: const Text('Battery drained'))),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _endRide,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RideMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: .8, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reachability {
  final ChargingPlace place;
  final double requiredRangeKm;
  const _Reachability(this.place, this.requiredRangeKm);
}

class _NoSavedPlaceNotice extends StatelessWidget {
  const _NoSavedPlaceNotice();

  @override
  Widget build(BuildContext context) => Card(
        child: const ListTile(
          leading: Icon(Icons.location_off_outlined),
          title: Text('No saved charging places'),
          subtitle: Text('Add Home, free, or paid places from the Charge tab.'),
        ),
      );
}
