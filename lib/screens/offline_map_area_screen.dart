import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Placeholder for the intentionally paused offline-map feature.
class OfflineMapAreaScreen extends StatefulWidget {
  final Directory tileCacheDir;
  final LatLng initialCenter;

  const OfflineMapAreaScreen({
    super.key,
    required this.tileCacheDir,
    required this.initialCenter,
  });

  @override
  State<OfflineMapAreaScreen> createState() => _OfflineMapAreaScreenState();
}

class _OfflineMapAreaScreenState extends State<OfflineMapAreaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline maps')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48),
              SizedBox(height: 16),
              Text('Offline maps are on hold',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                'RangeBuddy currently uses live OpenStreetMap tiles without an API key. Offline downloads will return with a map provider designed for offline use.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
