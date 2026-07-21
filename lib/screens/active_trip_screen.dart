import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/vehicle_alert_event.dart';
import '../services/range_engine.dart';
import '../services/trip_logger.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/stat_tile.dart';
import '../widgets/trip_route_map.dart';

class ActiveTripScreen extends StatefulWidget {
  final RangeEngine engine;
  final TripLogger logger;
  final String tripId;
  final double riderWeightKg;
  final double passengerWeightKg;
  final double totalMassKg;
  final Directory tileCacheDir;

  const ActiveTripScreen({
    super.key,
    required this.engine,
    required this.logger,
    required this.tripId,
    required this.riderWeightKg,
    required this.totalMassKg,
    required this.tileCacheDir,
    this.passengerWeightKg = 0,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  Duration _elapsed = Duration.zero;
  double _distanceKm = 0;
  double _rawSpeedKmh = 0;
  Timer? _clockTimer;
  final _stopwatch = Stopwatch();
  bool _starting = true;
  String? _errorMessage;
  final List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _startLogging();
  }

  Future<void> _startLogging() async {
    try {
      await widget.logger.startTrip(
        tripId: widget.tripId,
        riderWeightKg: widget.riderWeightKg,
        passengerWeightKg: widget.passengerWeightKg,
        onSample: _onSample,
      );
      _stopwatch.start();
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
      });
      setState(() => _starting = false);
    } on LocationPermissionDeniedException catch (e) {
      setState(() {
        _starting = false;
        _errorMessage = e.message;
      });
    }
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
    // Safety net: if the user backs out without tapping "End Ride",
    // don't leave the GPS stream running in the background forever.
    if (widget.logger.isLogging) {
      widget.logger.stopTrip();
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

  Future<void> _endRide() async {
    await widget.logger.stopTrip();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Active Ride')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BatteryTankGauge(
                percent: engine.batteryPercent(),
                rangeLabel:
                    '~${engine.estimatedRangeKmBaseline().toStringAsFixed(0)} km remaining',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatTile(
                    label: 'Distance',
                    value: '${_distanceKm.toStringAsFixed(1)} km',
                    icon: Icons.route,
                  ),
                  StatTile(
                    label: 'Elapsed',
                    value: _formatDuration(_elapsed),
                    icon: Icons.timer_outlined,
                  ),
                  StatTile(
                    label: 'Speed',
                    value: '${_rawSpeedKmh.toStringAsFixed(0)} km/h',
                    icon: Icons.speed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TripRouteMap(
                routePoints: _routePoints,
                currentPosition: _routePoints.isNotEmpty ? _routePoints.last : null,
                tileCacheDir: widget.tileCacheDir,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _promptBarDrop,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Bar Dropped'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _promptAlertEvent,
                      icon: const Icon(Icons.warning_amber_outlined),
                      label: const Text('Log Alert'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
