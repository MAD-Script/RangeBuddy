import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_tile_provider.dart';

/// Dark tile source matching the app's Material You dark aesthetic.
/// No API key needed for reasonable personal use.
const cartoDarkTileUrl =
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

/// Shared route map used by both the active trip screen (live,
/// growing route + current position) and the trip detail screen
/// (static, full route with start/end markers).
class TripRouteMap extends StatelessWidget {
  final List<LatLng> routePoints;
  final LatLng? currentPosition;
  final Directory tileCacheDir;
  final double height;

  const TripRouteMap({
    super.key,
    required this.routePoints,
    required this.tileCacheDir,
    this.currentPosition,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final center = currentPosition ??
        (routePoints.isNotEmpty ? routePoints.last : const LatLng(23.78, 90.40));

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: cartoDarkTileUrl,
              userAgentPackageName: 'com.evrangetracker.app',
              tileProvider: OfflineFirstTileProvider(cacheDir: tileCacheDir),
            ),
            if (routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (routePoints.isNotEmpty)
                  Marker(
                    point: routePoints.first,
                    child: const Icon(Icons.trip_origin, size: 16),
                  ),
                if (currentPosition != null)
                  Marker(
                    point: currentPosition!,
                    child: Icon(
                      Icons.electric_bike,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else if (routePoints.length > 1)
                  Marker(
                    point: routePoints.last,
                    child: const Icon(Icons.flag, size: 16),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
