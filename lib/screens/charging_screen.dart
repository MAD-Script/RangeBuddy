import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/charge_session.dart';
import '../models/charger_profile.dart';
import '../models/charging_place.dart';
import '../models/vehicle_profile.dart';
import '../services/range_engine.dart';
import 'charging_place_picker_screen.dart';

class ChargingScreen extends StatelessWidget {
  final VehicleProfile profile;
  final String profileKey;
  final RangeEngine engine;
  final Box<ChargerProfile> chargerBox;
  final Box<ChargeSession> sessionBox;
  final Box<ChargingPlace> placeBox;
  final VoidCallback onBatteryChanged;
  final Directory tileCacheDir;

  const ChargingScreen({
    super.key,
    required this.profile,
    required this.profileKey,
    required this.engine,
    required this.chargerBox,
    required this.sessionBox,
    required this.placeBox,
    required this.onBatteryChanged,
    required this.tileCacheDir,
  });

  Future<void> _addCharge(BuildContext context) async {
    final chargers = chargerBox.values
        .where((charger) => charger.profileKey == profileKey)
        .toList();
    if (chargers.isEmpty) {
      await _configureCharger(context);
      return;
    }

    final hours = TextEditingController();
    var selected = chargers.firstWhere(
      (charger) => charger.isDefault,
      orElse: () => chargers.first,
    );
    final result = await showDialog<_ChargeInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log charging'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<ChargerProfile>(
              value: selected,
              decoration: const InputDecoration(labelText: 'Charger'),
              items: [
                for (final charger in chargers)
                  DropdownMenuItem(
                    value: charger,
                    child: Text('${charger.name} · ${charger.wattage.toStringAsFixed(0)} W'),
                  ),
              ],
              onChanged: (charger) {
                if (charger != null) setDialogState(() => selected = charger);
              },
            ),
            TextField(
              controller: hours,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Charging time (hours)'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final duration = double.tryParse(hours.text);
                if (duration == null || duration <= 0) return;
                Navigator.pop(context, _ChargeInput(selected, duration));
              },
              child: const Text('Add charge'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final chargeBefore = engine.eRemainingWh;
    engine.addChargedEnergy(
      chargerWattage: result.charger.wattage,
      hoursCharged: result.hours,
      chargingEfficiency: result.charger.efficiency,
    );
    final recoveredWh = engine.eRemainingWh - chargeBefore;
    await sessionBox.add(ChargeSession(
      profileKey: profileKey,
      chargerName: result.charger.name,
      hours: result.hours,
      recoveredWh: recoveredWh,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
    onBatteryChanged();
  }

  Future<void> _configureCharger(BuildContext context) async {
    final name = TextEditingController(text: 'My charger');
    final watts = TextEditingController(text: '300');
    final efficiency = TextEditingController(text: '85');
    final existing = chargerBox.values
        .where((charger) => charger.profileKey == profileKey)
        .toList();
    final charger = await showDialog<ChargerProfile>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set up charger'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Save a charger once, then only enter charging time for each session.'),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Charger name')),
          TextField(controller: watts, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Output wattage')),
          TextField(controller: efficiency, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Charging efficiency (%)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final wattage = double.tryParse(watts.text);
              final efficiencyPercent = double.tryParse(efficiency.text);
              if (name.text.trim().isEmpty || wattage == null || wattage <= 0 || efficiencyPercent == null || efficiencyPercent <= 0 || efficiencyPercent > 100) return;
              Navigator.pop(context, ChargerProfile(
                profileKey: profileKey,
                name: name.text.trim(),
                wattage: wattage,
                efficiency: efficiencyPercent / 100,
                isDefault: existing.isEmpty,
              ));
            },
            child: const Text('Save charger'),
          ),
        ],
      ),
    );
    if (charger == null) return;
    await chargerBox.add(charger);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charger saved. Tap Log charge to record a session.')),
      );
    }
  }

  Future<void> _addPlace(BuildContext context) async {
    final method = await showDialog<_PlaceMethod>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose location'),
        content: const Text('Drop a pin on the map or paste a Google Maps link.'),
        actions: [
          TextButton.icon(onPressed: () => Navigator.pop(context, _PlaceMethod.googleLink), icon: const Icon(Icons.link), label: const Text('Google Maps link')),
          FilledButton.icon(onPressed: () => Navigator.pop(context, _PlaceMethod.map), icon: const Icon(Icons.map_outlined), label: const Text('Pick on map')),
        ],
      ),
    );
    if (method == null) return;
    LatLng? location;
    if (method == _PlaceMethod.map) {
      location = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (_) => ChargingPlacePickerScreen(tileCacheDir: tileCacheDir),
        ),
      );
    } else {
      location = await _locationFromGoogleLink(context);
    }
    if (location == null || !context.mounted) return;
    final selectedLocation = location;

    final name = TextEditingController();
    var isFree = true;
    final result = await showDialog<_PlaceInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add charging place'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name, e.g. Home')),
            Text('Pinned at ${selectedLocation.latitude.toStringAsFixed(5)}, ${selectedLocation.longitude.toStringAsFixed(5)}', style: Theme.of(context).textTheme.bodySmall),
            SwitchListTile(value: isFree, onChanged: (value) => setDialogState(() => isFree = value), title: const Text('Free charging'), contentPadding: EdgeInsets.zero),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, _PlaceInput(name.text.trim(), selectedLocation.latitude, selectedLocation.longitude, isFree));
            }, child: const Text('Save place')),
          ],
        ),
      ),
    );
    if (result == null) return;
    await placeBox.add(ChargingPlace(profileKey: profileKey, name: result.name, latitude: result.latitude, longitude: result.longitude, isFree: result.isFree));
  }

  Future<LatLng?> _locationFromGoogleLink(BuildContext context) async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Maps link'),
        content: TextField(controller: controller, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://maps.app.goo.gl/...')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Use link'))],
      ),
    );
    if (input == null || input.isEmpty) return null;
    try {
      var uri = Uri.parse(input);
      if (uri.host.contains('goo.gl') || uri.host.contains('google.com')) {
        final response = await http.get(uri);
        uri = response.request?.url ?? uri;
      }
      final text = uri.toString();
      final match = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)|!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)|[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(text);
      if (match == null) throw const FormatException('No coordinates found');
      final lat = double.parse(match.group(1) ?? match.group(3) ?? match.group(5)!);
      final lng = double.parse(match.group(2) ?? match.group(4) ?? match.group(6)!);
      return LatLng(lat, lng);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read a location from that Google Maps link.')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = sessionBox.values.where((s) => s.profileKey == profileKey).toList().reversed.toList();
    final places = placeBox.values.where((p) => p.profileKey == profileKey).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Charge', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addCharge(context), icon: const Icon(Icons.add), label: const Text('Log charge')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Icon(Icons.battery_charging_full_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${engine.batteryPercent().toStringAsFixed(0)}% predicted charge', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text('${engine.estimatedRangeKmBaseline().toStringAsFixed(0)} km estimated range · ${profile.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ]))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _Heading(label: 'SAVED CHARGERS', action: '${chargerBox.values.where((c) => c.profileKey == profileKey).length} saved')),
          TextButton.icon(onPressed: () => _configureCharger(context), icon: const Icon(Icons.tune, size: 17), label: const Text('Set up')),
        ]),
        if (chargerBox.values.where((c) => c.profileKey == profileKey).isEmpty)
          const _EmptyCard(icon: Icons.power_outlined, text: 'Set up your charger once so each charge log only needs its duration.'),
        for (final charger in chargerBox.values.where((c) => c.profileKey == profileKey))
          Card(child: ListTile(
            leading: const Icon(Icons.power_outlined),
            title: Text(charger.name),
            subtitle: Text('${charger.wattage.toStringAsFixed(0)} W · ${(charger.efficiency * 100).toStringAsFixed(0)}% efficient'),
            trailing: charger.isDefault ? const Text('DEFAULT') : null,
          )),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: _Heading(label: 'SAVED CHARGING PLACES', action: '${places.length} saved')), TextButton.icon(onPressed: () => _addPlace(context), icon: const Icon(Icons.add, size: 17), label: const Text('Add'))]),
        if (places.isEmpty) _EmptyCard(icon: Icons.location_on_outlined, text: 'Save Home, free, or paid charging places to plan your range.'),
        for (final place in places) Card(child: ListTile(leading: Icon(place.isFree ? Icons.home_rounded : Icons.payments_outlined), title: Text(place.name), subtitle: Text(place.isFree ? 'Free charging' : 'Paid charging'))),
        const SizedBox(height: 16),
        _Heading(label: 'CHARGING HISTORY', action: '${sessions.length} sessions'),
        if (sessions.isEmpty) const _EmptyCard(icon: Icons.history_rounded, text: 'Log a charge to update your virtual battery.'),
        for (final session in sessions) Card(child: ListTile(
          leading: const Icon(Icons.bolt_rounded),
          title: Text(session.chargerName),
          subtitle: Text('${session.hours.toStringAsFixed(1)} h · ${session.recoveredWh.toStringAsFixed(0)} Wh recovered'),
          trailing: Text('+${(session.recoveredWh / profile.baseWhPerKm).toStringAsFixed(0)} km', style: const TextStyle(fontWeight: FontWeight.w900)),
        )),
      ]),
    );
  }
}

class _ChargeInput { final ChargerProfile charger; final double hours; const _ChargeInput(this.charger, this.hours); }
class _PlaceInput { final String name; final double latitude; final double longitude; final bool isFree; const _PlaceInput(this.name, this.latitude, this.longitude, this.isFree); }
enum _PlaceMethod { map, googleLink }
class _Heading extends StatelessWidget { final String label; final String action; const _Heading({required this.label, required this.action}); @override Widget build(BuildContext context) => Row(children: [Text(label, style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)), const Spacer(), Text(action, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))]); }
class _EmptyCard extends StatelessWidget { final IconData icon; final String text; const _EmptyCard({required this.icon, required this.text}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))]))); }
