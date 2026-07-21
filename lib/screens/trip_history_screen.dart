import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip_metadata.dart';
import '../models/trip_sample.dart';
import '../models/bar_drop_event.dart';
import '../models/vehicle_alert_event.dart';
import '../services/trip_logger.dart';
import 'trip_detail_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TripHistoryScreen extends StatelessWidget {
  final Box<TripMetadata> metadataBox;
  final Box<TripSample> sampleBox;
  final Box<BarDropEvent> barDropBox;
  final Box<VehicleAlertEvent> alertBox;
  final TripLogger logger;
  final Directory tileCacheDir;

  const TripHistoryScreen({
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
      appBar: AppBar(title: const Text('Trip History')),
      body: ValueListenableBuilder(
        valueListenable: metadataBox.listenable(),
        builder: (context, Box<TripMetadata> box, _) {
          final trips = box.values.toList()
            ..sort((a, b) => b.startTimestampMs.compareTo(a.startTimestampMs));

          if (trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No rides logged yet. Start a ride from the Home tab '
                  'to begin collecting data.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
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
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
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
                  leading: const Icon(Icons.electric_bike),
                  title: Text(
                    '${start.day}/${start.month}/${start.year} '
                    '${start.hour.toString().padLeft(2, '0')}:'
                    '${start.minute.toString().padLeft(2, '0')}',
                  ),
                  subtitle: Text(
                    '$durationLabel · ${trip.startChargeType.name} → '
                    '${trip.endChargeType.name}'
                    '${trip.notes.isNotEmpty ? '\n${trip.notes}' : ''}',
                  ),
                  isThreeLine: trip.notes.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Export & share this trip\'s data',
                    onPressed: () => _exportAndShare(context, trip.tripId),
                  ),
                ),
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
}
