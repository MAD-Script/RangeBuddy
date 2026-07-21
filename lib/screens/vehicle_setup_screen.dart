import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../data/vehicle_catalog.dart';
import '../models/vehicle_profile.dart';
import '../services/tile_downloader.dart';
import '../widgets/trip_route_map.dart' show cartoDarkTileUrl;

/// Covers the Mirpur DOHS <-> Tongi College Gate commute corridor plus
/// a comfortable margin for detours/errands around Dhaka. Buffered
/// from your two real commute endpoints, not an arbitrary guess.
final defaultOfflineMapBounds = LatLngBounds(
  const LatLng(23.79, 90.32), // south-west
  const LatLng(23.96, 90.45), // north-east
);

class VehicleSetupScreen extends StatefulWidget {
  final VehicleProfile profile;
  final Directory tileCacheDir;

  const VehicleSetupScreen({
    super.key,
    required this.profile,
    required this.tileCacheDir,
  });

  @override
  State<VehicleSetupScreen> createState() => _VehicleSetupScreenState();
}

class _VehicleSetupScreenState extends State<VehicleSetupScreen> {
  late final _riderWeightController = TextEditingController(
    text: widget.profile.defaultRiderWeightKg.toStringAsFixed(0),
  );
  double? _downloadProgress; // null = not downloading

  Future<void> _saveRiderWeight() async {
    widget.profile.defaultRiderWeightKg =
        double.tryParse(_riderWeightController.text) ??
            widget.profile.defaultRiderWeightKg;
    await widget.profile.save();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  Future<void> _selectVehicle(VehicleCatalogEntry entry) async {
    widget.profile
      ..name = entry.displayName
      ..systemVoltage = entry.systemVoltage
      ..batteryAh = entry.batteryAh
      ..motorWattPeak = entry.motorWattPeak
      ..vehicleWeightKg = entry.vehicleWeightKg;
    await widget.profile.save();
    setState(() {});
  }

  Future<void> _downloadOfflineMap() async {
    final downloader = TileDownloader(
      urlTemplate: cartoDarkTileUrl,
      cacheDir: widget.tileCacheDir,
    );
    final estimate = downloader.estimate(defaultOfflineMapBounds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download offline map area'),
        content: Text(
          'This covers your Mirpur DOHS <-> Tongi commute corridor plus '
          'a margin around Dhaka.\n\n'
          '~${estimate.tileCount} tiles, roughly '
          '${estimate.estimatedMb.toStringAsFixed(0)}MB. Already-cached '
          'tiles are skipped, so re-running this later only fetches '
          'what\'s missing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _downloadProgress = 0);
    await for (final progress in downloader.download(defaultOfflineMapBounds)) {
      if (mounted) setState(() => _downloadProgress = progress.fraction);
    }
    if (mounted) {
      setState(() => _downloadProgress = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Offline map ready')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupCatalogByBrand();

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle & Rider')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Your weight', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _riderWeightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Rider weight (kg)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveRiderWeight(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saveRiderWeight,
              child: const Text('Save weight'),
            ),
          ),
          const Divider(height: 32),
          Text('Bike model', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Vehicle specs come from the catalog, not manual entry — '
            'weight/voltage/capacity are manufacturer facts.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          for (final brand in grouped.keys) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                brand,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            for (final entry in grouped[brand]!)
              RadioListTile<String>(
                value: entry.displayName,
                groupValue: widget.profile.name,
                onChanged: (_) => _selectVehicle(entry),
                title: Text(entry.model),
                subtitle: Text(
                  '${entry.systemVoltage.toStringAsFixed(0)}V · '
                  '${entry.batteryAh.toStringAsFixed(0)}Ah · '
                  '${entry.motorWattPeak.toStringAsFixed(0)}W · '
                  '${entry.vehicleWeightKg.toStringAsFixed(0)}kg',
                ),
              ),
          ],
          const Divider(height: 32),
          Text('Offline Map', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pre-download map tiles for your regular riding area so the '
            'map works with no signal.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (_downloadProgress != null) ...[
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 8),
            Text('${(_downloadProgress! * 100).toStringAsFixed(0)}%'),
          ] else
            OutlinedButton.icon(
              onPressed: _downloadOfflineMap,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download Offline Map Area'),
            ),
        ],
      ),
    );
  }
}
