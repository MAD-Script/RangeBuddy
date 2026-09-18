import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/tile_downloader.dart';
import '../widgets/trip_route_map.dart' show cartoDarkTileUrl, cartoLightTileUrl;
import '../services/offline_tile_provider.dart';

/// Lets the user pick which area to download for offline use by
/// panning/zooming the map — same interaction as Google Maps' "save
/// offline area": whatever's visible on screen when you confirm is
/// the area that gets downloaded, framed by the border overlay.
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
  final _mapController = MapController();
  LatLngBounds? _currentBounds;
  ({int tileCount, double estimatedMb})? _estimate;
  double? _downloadProgress;

  TileDownloader _downloaderFor(bool isDarkMode) => TileDownloader(
        urlTemplate: isDarkMode ? cartoDarkTileUrl : cartoLightTileUrl,
        cacheDir: widget.tileCacheDir,
      );

  void _recomputeEstimate(bool isDarkMode) {
    final bounds = _mapController.camera.visibleBounds;
    setState(() {
      _currentBounds = bounds;
      _estimate = _downloaderFor(isDarkMode).estimate(bounds);
    });
  }

  Future<void> _download(bool isDarkMode) async {
    final bounds = _currentBounds;
    if (bounds == null) return;

    setState(() => _downloadProgress = 0);
    await for (final progress
        in _downloaderFor(isDarkMode).download(bounds)) {
      if (mounted) setState(() => _downloadProgress = progress.fraction);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Offline map ready')));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDarkMode ? cartoDarkTileUrl : cartoLightTileUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Offline Area')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 13,
              onMapEvent: (_) => _recomputeEstimate(isDarkMode),
              onMapReady: () => _recomputeEstimate(isDarkMode),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.evrangetracker.app',
                tileProvider: OfflineFirstTileProvider(cacheDir: widget.tileCacheDir),
              ),
            ],
          ),
          // Frame overlay: purely visual, communicates "everything
          // currently visible is what gets downloaded" — ignores
          // touches so map gestures pass through underneath.
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pan and zoom to frame the area you want available '
                      'offline, then download.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (_estimate != null)
                      Text(
                        '~${_estimate!.tileCount} tiles, roughly '
                        '${_estimate!.estimatedMb.toStringAsFixed(0)}MB '
                        '(already-cached tiles are skipped)',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    const SizedBox(height: 12),
                    if (_downloadProgress != null) ...[
                      LinearProgressIndicator(value: _downloadProgress),
                      const SizedBox(height: 8),
                      Text('${(_downloadProgress! * 100).toStringAsFixed(0)}%'),
                    ] else
                      FilledButton.icon(
                        onPressed: () => _download(isDarkMode),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download This Area'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
