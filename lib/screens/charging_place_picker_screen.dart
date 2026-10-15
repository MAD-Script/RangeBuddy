import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/trip_route_map.dart';

/// Lets someone choose a saved charging point with a map tap rather than
/// asking them to find latitude/longitude themselves.
class ChargingPlacePickerScreen extends StatefulWidget {
  final Directory tileCacheDir;
  final LatLng initialCenter;

  const ChargingPlacePickerScreen({
    super.key,
    required this.tileCacheDir,
    this.initialCenter = const LatLng(23.78, 90.40),
  });

  @override
  State<ChargingPlacePickerScreen> createState() =>
      _ChargingPlacePickerScreenState();
}

class _ChargingPlacePickerScreenState extends State<ChargingPlacePickerScreen> {
  LatLng? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick charging location'),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, _selected),
            child: const Text('Save'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 14,
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: openStreetMapTileUrl,
                userAgentPackageName: 'com.madscript.rangebuddy',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 42),
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Pan to the place, then tap the map to drop a pin.'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
