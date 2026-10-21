import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip_metadata.dart';
import '../models/trip_sample.dart';
import '../models/bar_drop_event.dart';
import '../models/vehicle_alert_event.dart';
import '../services/trip_logger.dart';
import 'trip_detail_screen.dart';

class TripHistoryScreen extends StatelessWidget {
  final Box<TripMetadata> metadataBox;
  final Box<TripSample> sampleBox;
  final Box<BarDropEvent> barDropBox;
  final Box<VehicleAlertEvent> alertBox;
  final TripLogger logger;
  final Directory tileCacheDir;
  final ValueNotifier<bool> _showAll = ValueNotifier(false);

  TripHistoryScreen({
    super.key,
    required this.metadataBox,
    required this.sampleBox,
    required this.barDropBox,
    required this.alertBox,
    required this.logger,
    required this.tileCacheDir,
  });

  Future<void> _exportAndShare(BuildContext context, String tripId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await logger.exportTrip(tripId);
      await Share.shareXFiles(
        files.map((f) => XFile(f.path)).toList(),
        text: 'EV Range Tracker trip export: $tripId',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride history', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ValueListenableBuilder(
        valueListenable: metadataBox.listenable(),
        builder: (context, Box<TripMetadata> box, _) {
          final trips = box.values.toList()
            ..sort((a, b) => b.startTimestampMs.compareTo(a.startTimestampMs));

          if (trips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 14),
                    const Text('No rides yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Your completed rides will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }

          return AnimatedBuilder(
            animation: _showAll,
            builder: (context, _) {
              final visibleTrips = _showAll.value ? trips : trips.take(5).toList();
              return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: visibleTrips.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [
                  IconButton(icon: Icon(_showAll.value ? Icons.expand_less : Icons.expand_more), onPressed: () => _showAll.value = !_showAll.value),
                  Expanded(child: Text('${trips.length} RECORDED RIDE${trips.length == 1 ? '' : 'S'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  TextButton.icon(onPressed: () => _showHistoryNotice(context), icon: const Icon(Icons.bar_chart_rounded, size: 18), label: const Text('Detailed history')),
                ]));
              }
              final trip = visibleTrips[index - 1];
              final start =
                  DateTime.fromMillisecondsSinceEpoch(trip.startTimestampMs);
              final durationLabel = trip.endTimestampMs != null
                  ? _formatDuration(
                      Duration(
                        milliseconds:
                            trip.endTimestampMs! - trip.startTimestampMs,
                      ),
                    )
                  : 'In progress';

              return Card(
                color: trip.isCalibrationRide ? const Color(0xFFFFF3CD) : null,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripDetailScreen(
                        tripId: trip.tripId,
                        sampleBox: sampleBox,
                        metadataBox: metadataBox,
                        barDropBox: barDropBox,
                        alertBox: alertBox,
                        tileCacheDir: tileCacheDir,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
                          child: Icon(Icons.electric_bike_rounded, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}${trip.isCalibrationRide ? '  ·  CALIBRATION RIDE' : ''}', style: TextStyle(fontWeight: FontWeight.w900, color: trip.isCalibrationRide ? const Color(0xFF8A6400) : null)),
                              const SizedBox(height: 3),
                              Text('$durationLabel  ·  ${trip.startChargeType.name} → ${trip.endChargeType.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              if (trip.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(trip.notes, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.ios_share_rounded),
                          tooltip: 'Export this ride',
                          onPressed: () => _exportAndShare(context, trip.tripId),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    return '${d.inHours}h ${m}m';
  }

  void _showHistoryNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detailed ride charts are being prepared from your recorded distance and charge data.')));
  }
}
