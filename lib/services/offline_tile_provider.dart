import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// A tile provider that serves a tile from a locally pre-downloaded
/// file if one exists, falling back to the network otherwise.
///
/// This is deliberately NOT using flutter_map_tile_caching — that
/// package depends on ObjectBox (a native database), which adds
/// another native-build surface on top of the Kotlin toolchain issues
/// you already fought through. This plain-file approach uses nothing
/// but FileImage/NetworkImage, both simple and stable.
class OfflineFirstTileProvider extends TileProvider {
  final Directory cacheDir;

  OfflineFirstTileProvider({required this.cacheDir});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = tileFile(
      cacheDir,
      coordinates.z.toInt(),
      coordinates.x.toInt(),
      coordinates.y.toInt(),
    );
    if (file.existsSync()) {
      return FileImage(file);
    }
    final url = getTileUrl(coordinates, options);
    return NetworkImage(url);
  }
}

/// Where a given tile is/would be stored on disk. Shared between the
/// live tile provider (reads) and TileDownloader (writes) so both
/// agree on the same file layout.
File tileFile(Directory cacheDir, int z, int x, int y) {
  return File('${cacheDir.path}/map_tiles/$z/$x/$y.png');
}
