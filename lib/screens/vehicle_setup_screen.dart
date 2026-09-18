import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/vehicle_catalog.dart';
import '../models/vehicle_profile.dart';
import 'offline_map_area_screen.dart';

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
      ..vehicleWeightKg = entry.vehicleWeightKg
      ..topSpeedKmh = entry.topSpeedKmh;
    await widget.profile.save();
    setState(() {});
  }

  Future<void> _openOfflineMapPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfflineMapAreaScreen(
          tileCacheDir: widget.tileCacheDir,
          // Starting view: Dhaka, roughly your usual riding area — you
          // can pan/zoom anywhere from here before downloading.
          initialCenter: const LatLng(23.87, 90.38),
        ),
      ),
    );
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
            'Choose exactly which area to make available offline by '
            'panning and zooming, same as saving an offline area in '
            'Google Maps.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openOfflineMapPicker,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Select Offline Map Area'),
          ),
        ],
      ),
    );
  }
}
