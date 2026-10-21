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
  final Future<void> Function() onFullCharge;
  final bool isCalibrationActive;
  final Directory tileCacheDir;
  final ValueNotifier<_SessionFilter> _filter =
      ValueNotifier(_SessionFilter.month);
  final ValueNotifier<bool> _showAllChargers = ValueNotifier(false);
  final ValueNotifier<bool> _showAllPlaces = ValueNotifier(false);

  ChargingScreen({
    super.key,
    required this.profile,
    required this.profileKey,
    required this.engine,
    required this.chargerBox,
    required this.sessionBox,
    required this.placeBox,
    required this.onBatteryChanged,
    required this.onFullCharge,
    this.isCalibrationActive = false,
    required this.tileCacheDir,
  });

  Future<void> _addCharge(BuildContext context) async {
    if (isCalibrationActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Charging is disabled until this calibration ride ends with Battery drained.')));
      return;
    }
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
    final startPercent = engine.batteryPercent();
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
      startPercent: startPercent,
      endPercent: engine.batteryPercent(),
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
      String responseBody = '';
      if (uri.host.contains('goo.gl') || uri.host.contains('google.com')) {
        final request = http.Request('GET', uri)
          ..headers['User-Agent'] = 'RangeBuddy/1.0 (location picker)'
          ..headers['Accept'] = 'text/html,application/xhtml+xml';
        final response = await http.Client().send(request);
        uri = response.request?.url ?? uri;
        responseBody = await response.stream.bytesToString();
      }
      final location = _locationFromGoogleMapText('$uri\n$responseBody');
      if (location == null) throw const FormatException('No coordinates found');
      return location;
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read a location from that Google Maps link.')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charge', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addCharge(context), icon: const Icon(Icons.add), label: const Text('Log charge')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          chargerBox.listenable(),
          sessionBox.listenable(),
          placeBox.listenable(),
          _filter,
          _showAllChargers,
          _showAllPlaces,
        ]),
        builder: (context, _) {
          final sessions = sessionBox.values
              .where((s) => s.profileKey == profileKey)
              .where((s) => _inFilter(s, _filter.value))
              .toList()
              .reversed
              .toList();
          final places = placeBox.values.where((p) => p.profileKey == profileKey).toList();
          final chargers = chargerBox.values.where((c) => c.profileKey == profileKey).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Icon(Icons.battery_charging_full_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${engine.batteryPercent().toStringAsFixed(0)}% predicted charge', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text('${engine.estimatedRangeKmBaseline().toStringAsFixed(0)} km estimated range · ${profile.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ]))),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: isCalibrationActive ? null : () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Log full charge?'),
                content: const Text('This records a 7 h 30 min full charge and only restores the amount currently missing.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm full charge')),
                ],
              ),
            );
            if (confirm == true) await onFullCharge();
          },
          icon: const Icon(Icons.battery_charging_full_rounded),
          label: const Text('CONFIRM FULL CHARGE · 7h 30m'),
        ),
        const SizedBox(height: 20),
        Row(children: [
          IconButton(icon: Icon(_showAllChargers.value ? Icons.expand_less : Icons.expand_more), onPressed: () => _showAllChargers.value = !_showAllChargers.value),
          Expanded(child: _Heading(label: 'SAVED CHARGERS', action: '${chargers.length} saved')),
          TextButton.icon(onPressed: () => _configureCharger(context), icon: const Icon(Icons.tune, size: 17), label: const Text('Set up')),
        ]),
        if (chargers.isEmpty)
          const _EmptyCard(icon: Icons.power_outlined, text: 'Set up your charger once so each charge log only needs its duration.'),
        if (chargers.isNotEmpty) Wrap(
          spacing: 8, runSpacing: 6,
          children: [for (final charger in (_showAllChargers.value ? chargers : chargers.take(3)))
            InputChip(
              avatar: const Icon(Icons.power_outlined, size: 17),
              label: Text('${charger.name} · ${charger.wattage.toStringAsFixed(0)}W'),
              onDeleted: () async {
                if (await _confirmDeletion(context, 'charger', charger.name)) {
                  await charger.delete();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          IconButton(icon: Icon(_showAllPlaces.value ? Icons.expand_less : Icons.expand_more), onPressed: () => _showAllPlaces.value = !_showAllPlaces.value),
          Expanded(child: _Heading(label: 'SAVED PLACES', action: '${places.length} saved')),
          TextButton.icon(onPressed: () => _addPlace(context), icon: const Icon(Icons.add, size: 17), label: const Text('Add')),
        ]),
        if (places.isEmpty) _EmptyCard(icon: Icons.location_on_outlined, text: 'Save Home, free, or paid charging places to plan your range.'),
        if (places.isNotEmpty) Wrap(
          spacing: 8, runSpacing: 6,
          children: [for (final place in (_showAllPlaces.value ? places : places.take(6)))
            InputChip(
              avatar: Icon(place.isFree ? Icons.home_rounded : Icons.payments_outlined, size: 17),
              label: Text(place.name),
              onDeleted: () async {
                if (await _confirmDeletion(context, 'saved place', place.name)) {
                  await place.delete();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: _Heading(label: 'CHARGING HISTORY', action: '')),
          DropdownButton<_SessionFilter>(
            value: _filter.value,
            underline: const SizedBox(),
            onChanged: (value) { if (value != null) _filter.value = value; },
            items: const [
              DropdownMenuItem(value: _SessionFilter.month, child: Text('This month')),
              DropdownMenuItem(value: _SessionFilter.year, child: Text('This year')),
              DropdownMenuItem(value: _SessionFilter.all, child: Text('All time')),
            ],
          ),
        ]),
        if (sessions.isEmpty) const _EmptyCard(icon: Icons.history_rounded, text: 'Log a charge to update your virtual battery.'),
        for (final session in sessions)
          _DeleteOnSwipe(
            dismissKey: ValueKey('charge-${session.key}'),
            label: 'charge session',
            onDelete: session.delete,
            child: _ChargeSessionCard(session: session, profile: profile),
          ),
          ]);
        },
      ),
    );
  }
}

class _ChargeInput { final ChargerProfile charger; final double hours; const _ChargeInput(this.charger, this.hours); }
class _PlaceInput { final String name; final double latitude; final double longitude; final bool isFree; const _PlaceInput(this.name, this.latitude, this.longitude, this.isFree); }
enum _PlaceMethod { map, googleLink }
enum _SessionFilter { month, year, all }

Future<bool> _confirmDeletion(
  BuildContext context,
  String kind,
  String name,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete $kind?'),
          content: Text('Remove “$name”? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

bool _inFilter(ChargeSession session, _SessionFilter filter) {
  final when = DateTime.fromMillisecondsSinceEpoch(session.timestampMs);
  final now = DateTime.now();
  return switch (filter) {
    _SessionFilter.all => true,
    _SessionFilter.year => when.year == now.year,
    _SessionFilter.month => when.year == now.year && when.month == now.month,
  };
}
class _Heading extends StatelessWidget { final String label; final String action; const _Heading({required this.label, required this.action}); @override Widget build(BuildContext context) => Row(children: [Text(label, style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)), const Spacer(), Text(action, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))]); }
class _EmptyCard extends StatelessWidget { final IconData icon; final String text; const _EmptyCard({required this.icon, required this.text}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))]))); }

class _ChargeSessionCard extends StatelessWidget {
  final ChargeSession session;
  final VehicleProfile profile;
  const _ChargeSessionCard({required this.session, required this.profile});

  @override
  Widget build(BuildContext context) {
    final start = session.startPercent ??
        ((session.endPercent ?? 100) -
                session.recoveredWh / profile.totalEnergyWh() * 100)
            .clamp(0, 100);
    final end = session.endPercent ??
        (start + session.recoveredWh / profile.totalEnergyWh() * 100)
            .clamp(0, 100);
    final delta = end - start;
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime.fromMillisecondsSinceEpoch(session.timestampMs);
    final duration = Duration(minutes: (session.hours * 60).round());
    final label = '${duration.inHours}h ${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Charged for $label', style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${date.day}/${date.month}/${date.year}', style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('${start.toStringAsFixed(0)}% to ${end.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
            Text('+${delta.toStringAsFixed(0)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: scheme.primary)),
          ]),
          const SizedBox(height: 6),
          Text('${session.chargerName} · ${session.recoveredWh.toStringAsFixed(0)} Wh recovered'),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: end / 100, minHeight: 9)),
        ]),
      ),
    );
  }
}

class _DeleteOnSwipe extends StatelessWidget {
  final Key dismissKey;
  final String label;
  final Future<void> Function() onDelete;
  final Widget child;

  const _DeleteOnSwipe({required this.dismissKey, required this.label, required this.onDelete, required this.child});

  @override
  Widget build(BuildContext context) => Dismissible(
    key: dismissKey,
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onError),
    ),
    confirmDismiss: (_) async => await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false,
    onDismissed: (_) => onDelete(),
    child: child,
  );
}

LatLng? _locationFromGoogleMapText(String text) {
  final decoded = Uri.decodeFull(text);
  final coordinateMatch = RegExp(
    r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)|!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)|[?&](?:q|query|ll)=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  ).firstMatch(decoded);
  if (coordinateMatch != null) {
    return LatLng(
      double.parse(coordinateMatch.group(1) ?? coordinateMatch.group(3) ?? coordinateMatch.group(5)!),
      double.parse(coordinateMatch.group(2) ?? coordinateMatch.group(4) ?? coordinateMatch.group(6)!),
    );
  }
  final plusCode = RegExp(r'([23456789CFGHJMPQRVWX]{8}\+[23456789CFGHJMPQRVWX]{2,})', caseSensitive: false).firstMatch(decoded)?.group(1);
  return plusCode == null ? null : _decodePlusCode(plusCode);
}

/// Decodes a full Open Location Code (Google Maps Plus Code) locally, without
/// an API key. Short local codes need a locality context, which Google short
/// links provide after redirecting to their full latitude/longitude URL.
LatLng? _decodePlusCode(String input) {
  const alphabet = '23456789CFGHJMPQRVWX';
  final code = input.toUpperCase().replaceAll('+', '');
  if (code.length < 8 ||
      code.split('').any((char) => !alphabet.contains(char))) {
    return null;
  }
  var latitude = -90.0;
  var longitude = -180.0;
  var latitudeResolution = 20.0;
  var longitudeResolution = 20.0;
  final pairLength = code.length < 10 ? code.length : 10;
  for (var index = 0; index < pairLength; index += 2) {
    if (index + 1 >= pairLength) return null;
    latitude += alphabet.indexOf(code[index]) * latitudeResolution;
    longitude += alphabet.indexOf(code[index + 1]) * longitudeResolution;
    latitudeResolution /= 20;
    longitudeResolution /= 20;
  }
  for (var index = 10; index < code.length; index++) {
    final value = alphabet.indexOf(code[index]);
    latitudeResolution /= 5;
    longitudeResolution /= 4;
    latitude += (value ~/ 4) * latitudeResolution;
    longitude += (value % 4) * longitudeResolution;
  }
  return LatLng(latitude + latitudeResolution / 2, longitude + longitudeResolution / 2);
}
