import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip_sample.dart';
import '../models/trip_metadata.dart';
import '../models/bar_drop_event.dart';
import '../models/vehicle_alert_event.dart';
import '../services/trip_stats.dart';
import '../widgets/trip_route_map.dart';
import '../widgets/stat_tile.dart';

class TripDetailScreen extends StatelessWidget {
  final String tripId;
  final Box<TripSample> sampleBox;
  final Box<TripMetadata> metadataBox;
  final Box<BarDropEvent> barDropBox;
  final Box<VehicleAlertEvent> alertBox;
  final Directory tileCacheDir;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    required this.sampleBox,
    required this.metadataBox,
    required this.barDropBox,
    required this.alertBox,
    required this.tileCacheDir,
  });

  static const _alertLabels = {
    VehicleAlertType.lowBatteryAudibleWarning: 'Low-battery audible warning',
    VehicleAlertType.refuelIndicatorOn: 'Refuel indicator turned on',
    VehicleAlertType.criticalBlinkingRed: 'Last bar blinking red (critical)',
  };

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    return d.inHours > 0 ? '${d.inHours}h ${m}m' : '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final samples = sampleBox.values.where((s) => s.tripId == tripId).toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final meta = metadataBox.get(tripId);
    final bars = barDropBox.values.where((b) => b.tripId == tripId).toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final alerts = alertBox.values.where((a) => a.tripId == tripId).toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    final stats = TripStats.fromSamples(samples);
    final routePoints = [
      for (final s in samples) LatLng(s.latitude, s.longitude),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Detail')),
      body: samples.isEmpty
          ? const Center(child: Text('No GPS data recorded for this trip.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TripRouteMap(
                  routePoints: routePoints,
                  tileCacheDir: tileCacheDir,
                  height: 240,
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.6,
                  children: [
                    StatTile(
                      label: 'Distance',
                      value: '${stats.distanceKm.toStringAsFixed(1)} km',
                      icon: Icons.route,
                    ),
                    StatTile(
                      label: 'Duration',
                      value: _formatDuration(stats.duration),
                      icon: Icons.timer_outlined,
                    ),
                    StatTile(
                      label: 'Avg speed',
                      value: '${stats.avgSpeedKmh.toStringAsFixed(0)} km/h',
                      icon: Icons.speed,
                    ),
                    StatTile(
                      label: 'Max speed',
                      value: '${stats.maxSpeedKmh.toStringAsFixed(0)} km/h',
                      icon: Icons.speed_outlined,
                    ),
                    StatTile(
                      label: 'Times stopped',
                      value: '${stats.stopCount}',
                      icon: Icons.pause_circle_outline,
                    ),
                    StatTile(
                      label: 'Elevation gain',
                      value: '${stats.elevationGainM.toStringAsFixed(0)} m',
                      icon: Icons.terrain,
                    ),
                  ],
                ),
                if (meta != null && meta.notes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(meta.notes),
                ],
                if (bars.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Bar drops', style: Theme.of(context).textTheme.titleSmall),
                  for (final b in bars)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flag_outlined, size: 20),
                      title: Text('Dropped to bar ${b.barLevelAfterDrop}'),
                      trailing: Text(
                        DateTime.fromMillisecondsSinceEpoch(b.timestampMs)
                            .toString()
                            .substring(11, 16),
                      ),
                    ),
                ],
                if (alerts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Alerts', style: Theme.of(context).textTheme.titleSmall),
                  for (final a in alerts)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.warning_amber_outlined, size: 20),
                      title: Text(_alertLabels[a.alertType] ?? a.alertType.name),
                      trailing: Text(
                        DateTime.fromMillisecondsSinceEpoch(a.timestampMs)
                            .toString()
                            .substring(11, 16),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
