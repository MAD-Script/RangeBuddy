import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_tile_provider.dart';

/// CARTO Basemap URLs — switches with the app's light/dark theme
/// rather than being locked to dark always.
const cartoLightTileUrl =
    'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
const cartoDarkTileUrl =
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

/// Shared route map used by both the active trip screen (live, locked
/// to follow the current position, non-interactive) and the trip
/// detail / offline-area screens (freely pannable/zoomable).
class TripRouteMap extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng? currentPosition;
  final Directory tileCacheDir;
  final double height;

  /// When false, all pan/zoom/rotate gestures are disabled — use this
  /// during an active ride so the map can't be accidentally dragged
  /// away from the rider's position mid-trip.
  final bool interactive;

  /// When true, the camera automatically re-centers on
  /// [currentPosition] whenever it updates, like a live navigation
  /// view. Has no effect if interactive is also true (the user's own
  /// panning would fight with it), so this is meant for the locked,
  /// non-interactive active-trip case.
  final bool followCurrentPosition;

  const TripRouteMap({
    super.key,
    required this.routePoints,
    required this.tileCacheDir,
    this.currentPosition,
    this.height = 220,
    this.interactive = true,
    this.followCurrentPosition = false,
  });

  @override
  State<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<TripRouteMap> {
  final _mapController = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(TripRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followCurrentPosition &&
        _mapReady &&
        widget.currentPosition != null &&
        widget.currentPosition != oldWidget.currentPosition) {
      _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentPosition ??
        (widget.routePoints.isNotEmpty
            ? widget.routePoints.last
            : const LatLng(23.78, 90.40));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDarkMode ? cartoDarkTileUrl : cartoLightTileUrl;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            onMapReady: () => _mapReady = true,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.evrangetracker.app',
              tileProvider: OfflineFirstTileProvider(cacheDir: widget.tileCacheDir),
            ),
            if (widget.routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 4,
                    // A subtle border keeps the line visible even if the
                    // dynamic Material You primary color happens to be
                    // close to the tile background on either theme.
                    borderColor: isDarkMode ? Colors.black54 : Colors.white70,
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.routePoints.isNotEmpty)
                  Marker(
                    point: widget.routePoints.first,
                    child: const Icon(Icons.trip_origin, size: 16),
                  ),
                if (widget.currentPosition != null)
                  Marker(
                    point: widget.currentPosition!,
                    child: _LiveLocationDot(color: Theme.of(context).colorScheme.primary),
                  )
                else if (widget.routePoints.length > 1)
                  Marker(
                    point: widget.routePoints.last,
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

/// A blue dot with a white ring — the standard "you are here" marker
/// style, distinct from the plain start/end flag icons used for
/// historical (non-live) route views. Kept small and tight so it
/// reads as a location dot, not a blob.
class _LiveLocationDot extends StatelessWidget {
  final Color color;
  const _LiveLocationDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, spreadRadius: 0.5),
        ],
      ),
    );
  }
}
