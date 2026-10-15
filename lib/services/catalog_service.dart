import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../data/vehicle_catalog.dart';

/// Versioned public catalog. A bad or unavailable remote response never
/// replaces the last known-good cached catalog or the bundled F52 fallback.
class CatalogService {
  static const remoteUrl = String.fromEnvironment(
    'RANGEBUDDY_CATALOG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/MAD-Script/RangeBuddy/main/catalog/rangebuddy_catalog.json',
  );
  static const _cacheKey = 'vehicle_catalog_json';

  final Box<String> settings;
  CatalogService(this.settings);

  List<VehicleCatalogEntry> cachedOrBundled() {
    final raw = settings.get(_cacheKey);
    if (raw == null) return vehicleCatalog;
    try {
      return _parse(raw);
    } catch (_) {
      return vehicleCatalog;
    }
  }

  Future<List<VehicleCatalogEntry>> refresh() async {
    if (remoteUrl.isEmpty) return cachedOrBundled();
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode != 200) {
      throw StateError('Catalog returned ${response.statusCode}');
    }
    final entries = _parse(response.body);
    await settings.put(_cacheKey, response.body);
    return entries;
  }

  List<VehicleCatalogEntry> _parse(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final bikes = decoded['bikes'];
    if (bikes is! List || bikes.isEmpty) throw const FormatException('No bikes');
    return bikes
        .whereType<Map<String, dynamic>>()
        .map(VehicleCatalogEntry.fromJson)
        .toList();
  }
}
