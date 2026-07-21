import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'offline_tile_provider.dart' show tileFile;
import 'package:flutter_map/flutter_map.dart';

class TileDownloadProgress {
  final int downloaded;
  final int total;
  const TileDownloadProgress(this.downloaded, this.total);
  double get fraction => total == 0 ? 0 : downloaded / total;
}

class _TileXYZ {
  final int z, x, y;
  const _TileXYZ(this.z, this.x, this.y);
}

/// Downloads all tiles covering a lat/lng bounding box across a zoom
/// range for offline use, skipping tiles already cached from a
/// previous run. Uses standard Slippy Map (Web Mercator) tile math —
/// the same numbering scheme every OSM-style tile server uses.
class TileDownloader {
  final String urlTemplate; // must contain {z}, {x}, {y}
  final Directory cacheDir;

  TileDownloader({required this.urlTemplate, required this.cacheDir});

  _TileXYZ _latLngToTile(double lat, double lng, int z) {
    final n = math.pow(2, z).toDouble();
    final x = ((lng + 180) / 360 * n).floor();
    final latRad = lat * math.pi / 180;
    final y = ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            n)
        .floor();
    return _TileXYZ(z, x, y);
  }

  List<_TileXYZ> _tilesForBounds(LatLngBounds bounds, int minZoom, int maxZoom) {
    final tiles = <_TileXYZ>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final nw = _latLngToTile(bounds.north, bounds.west, z);
      final se = _latLngToTile(bounds.south, bounds.east, z);
      for (var x = nw.x; x <= se.x; x++) {
        for (var y = nw.y; y <= se.y; y++) {
          tiles.add(_TileXYZ(z, x, y));
        }
      }
    }
    return tiles;
  }

  /// Estimates total tile count (and rough MB) before committing to a
  /// download — show this to the user so they know what they're
  /// agreeing to before it starts.
  ({int tileCount, double estimatedMb}) estimate(
    LatLngBounds bounds, {
    int minZoom = 12,
    int maxZoom = 16,
  }) {
    final count = _tilesForBounds(bounds, minZoom, maxZoom).length;
    // ~15KB/tile is a reasonable average for compressed raster tiles.
    return (tileCount: count, estimatedMb: count * 15 / 1024);
  }

  Stream<TileDownloadProgress> download(
    LatLngBounds bounds, {
    int minZoom = 12,
    int maxZoom = 16,
  }) async* {
    final tiles = _tilesForBounds(bounds, minZoom, maxZoom);
    var done = 0;
    yield TileDownloadProgress(done, tiles.length);

    for (final t in tiles) {
      final file = tileFile(cacheDir, t.z, t.x, t.y);
      if (!await file.exists()) {
        try {
          await file.parent.create(recursive: true);
          final url = urlTemplate
              .replaceAll('{z}', '${t.z}')
              .replaceAll('{x}', '${t.x}')
              .replaceAll('{y}', '${t.y}');
          final response = await http
              .get(Uri.parse(url), headers: {'User-Agent': 'ev_range_tracker'});
          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
          }
        } catch (_) {
          // Skip a failed tile rather than aborting the whole
          // download — a few missing tiles just mean a small blank
          // patch on the map, not a crash.
        }
      }
      done++;
      yield TileDownloadProgress(done, tiles.length);
    }
  }
}
