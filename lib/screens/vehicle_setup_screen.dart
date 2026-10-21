import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../data/vehicle_catalog.dart';
import '../models/vehicle_profile.dart';
import '../services/github_release_service.dart';
import '../services/catalog_service.dart';
import '../services/calibration_export_service.dart';
import '../models/battery_state.dart';
import '../models/charge_session.dart';
import 'battery_health_screen.dart';

class VehicleSetupScreen extends StatefulWidget {
  final VehicleProfile profile;
  final Box<VehicleProfile> profileBox;
  final String selectedProfileKey;
  final ValueChanged<String> onProfileSelected;
  final Box<String> appSettingsBox;
  final String profileKey;
  final Box<BatteryState> batteryStateBox;
  final Box<ChargeSession> chargeSessionBox;
  final Directory tileCacheDir;
  final VoidCallback onStartCalibration;
  final VoidCallback onConfirmFullCharge;

  const VehicleSetupScreen({
    super.key,
    required this.profile,
    required this.profileBox,
    required this.selectedProfileKey,
    required this.onProfileSelected,
    required this.appSettingsBox,
    required this.profileKey,
    required this.batteryStateBox,
    required this.chargeSessionBox,
    required this.tileCacheDir,
    required this.onStartCalibration,
    required this.onConfirmFullCharge,
  });

  @override
  State<VehicleSetupScreen> createState() => _VehicleSetupScreenState();
}

class _VehicleSetupScreenState extends State<VehicleSetupScreen> {
  late final TextEditingController _riderWeightController;
  late List<VehicleCatalogEntry> _catalog;

  @override
  void initState() {
    super.initState();
    _riderWeightController = TextEditingController(
      text: widget.profile.defaultRiderWeightKg.toStringAsFixed(0),
    );
    _catalog = CatalogService(widget.appSettingsBox).cachedOrBundled();
  }

  @override
  void didUpdateWidget(covariant VehicleSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfileKey != widget.selectedProfileKey) {
      _riderWeightController.text =
          widget.profile.defaultRiderWeightKg.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _riderWeightController.dispose();
    super.dispose();
  }

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
      ..topSpeedKmh = entry.topSpeedKmh
      ..isVerified = true
      ..catalogId = entry.id;
    await widget.profile.save();
    setState(() {});
  }

  Future<void> _createManualProfile() async {
    final name = TextEditingController();
    final voltage = TextEditingController(text: '72');
    final capacity = TextEditingController(text: '20');
    final range = TextEditingController(text: '60');
    final result = await showDialog<VehicleProfile>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an unverified bike'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Make and model')),
          TextField(controller: voltage, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Battery voltage (V)')),
          TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Battery capacity (Ah)')),
          TextField(controller: range, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Known full range (km)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final v = double.tryParse(voltage.text);
            final ah = double.tryParse(capacity.text);
            final km = double.tryParse(range.text);
            if (name.text.trim().isEmpty || v == null || ah == null || km == null || v <= 0 || ah <= 0 || km <= 0) return;
            Navigator.pop(context, VehicleProfile(name: name.text.trim(), systemVoltage: v, batteryAh: ah, baseWhPerKm: (v * ah) / km, isVerified: false, catalogId: null));
          }, child: const Text('Create profile')),
        ],
      ),
    );
    if (result == null) return;
    final key = await widget.profileBox.add(result);
    widget.onProfileSelected(key.toString());
  }

  Future<void> _copyBikeRequest() async {
    const repository = String.fromEnvironment(
      'RANGEBUDDY_GITHUB_REPOSITORY',
      defaultValue: 'MAD-Script/RangeBuddy',
    );
    const template = '## Missing bike request\n\n'
        '- Make:\n- Model:\n- Country/market:\n- Battery voltage (if known):\n'
        '- Battery capacity (Ah, if known):\n- Motor power (if known):\n'
        '- Known full range (if tested):\n\n'
        'I understand that submitted specifications will be reviewed before '
        'they are added to RangeBuddy\'s verified catalog.';
    await Clipboard.setData(const ClipboardData(text: template));
    if (!mounted) return;
    final hint = repository.isEmpty
        ? 'Bike-request template copied. Paste it into a GitHub issue for RangeBuddy.'
        : 'Bike-request template copied. Open github.com/$repository/issues/new and paste it.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
  }

  Future<void> _refreshCatalog() async {
    try {
      final catalog = await CatalogService(widget.appSettingsBox).refresh();
      if (mounted) {
        setState(() => _catalog = catalog);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bike catalog updated.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Catalog update failed: $error')));
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final release = await GitHubReleaseService().latestRelease();
      if (!mounted) return;
      if (release == null) return;
      if (!release.isNewerThanInstalled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RangeBuddy is already up to date.')));
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('RangeBuddy ${release.version}'),
          content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(release.notes),
            const SizedBox(height: 16),
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: release.pageUrl)), icon: const Icon(Icons.link), label: const Text('Copy GitHub release link')),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            if (release.apkUrl != null)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await AndroidUpdateInstaller().downloadAndInstall(release);
                  } catch (error) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $error')));
                  }
                },
                child: const Text('Download update'),
              ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check updates: $error')),
        );
      }
    }
  }

  Future<void> _shareCalibration() async {
    try {
      final file = await CalibrationExportService().createBundle(
        profile: widget.profile,
        profileKey: widget.profileKey,
        states: widget.batteryStateBox,
        sessions: widget.chargeSessionBox,
      );
      await Share.shareXFiles([XFile(file.path)], text: 'RangeBuddy anonymous calibration export');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create export: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupCatalogByBrand(_catalog);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bike settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.electric_bike_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.profile.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${widget.profile.systemVoltage.toStringAsFixed(0)}V  ·  ${widget.profile.batteryAh.toStringAsFixed(0)}Ah  ·  ${widget.profile.topSpeedKmh.toStringAsFixed(0)} km/h', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('BATTERY', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BatteryHealthScreen(profile: widget.profile, profileKey: widget.profileKey, batteryStates: widget.batteryStateBox, sessions: widget.chargeSessionBox))),
            leading: const Icon(Icons.favorite_rounded), title: const Text('Battery health', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Capacity estimate, wear and calibration guidance'), trailing: const Icon(Icons.chevron_right_rounded),
          )),
          const SizedBox(height: 20),
          Text('CALIBRATION', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            ListTile(
              onTap: widget.onConfirmFullCharge,
              leading: const Icon(Icons.battery_charging_full_rounded),
              title: const Text('Confirm full charge', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Resets the virtual battery to 100% for this bike — the main way to correct drift.'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: widget.appSettingsBox.get('calibration_mode_${widget.profileKey}') == 'true',
              onChanged: (enabled) async {
                if (!enabled) {
                  final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Turn off calibration mode?'), content: const Text('An incomplete calibration will not improve battery health. You can enable it again later.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep on')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Turn off'))]));
                  if (confirm != true) return;
                }
                await widget.appSettingsBox.put('calibration_mode_${widget.profileKey}', enabled.toString());
                if (mounted) setState(() {});
              },
              title: const Text('Calibration mode', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Make Start Ride begin a guided calibration ride.'),
            ),
            const Divider(height: 1),
            ListTile(
              onTap: () async {
                final proceed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                  title: const Text('Before calibration'),
                  content: const Text('Confirm a full charge first. You may ride with passengers. Do not log any charge during calibration. End only after Battery drained, when the bike is crawling at roughly 5–10 km/h.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start'))],
                ));
                if (proceed == true) widget.onStartCalibration();
              },
              leading: const Icon(Icons.rule_rounded),
              title: const Text('Start calibration ride', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('A ride flagged for extra calibration prompts, to sharpen prediction accuracy.'),
            ),
          ])),
          const SizedBox(height: 20),
          Text('MY BIKES', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            for (final key in widget.profileBox.keys)
              RadioListTile<String>(
                value: key.toString(),
                groupValue: widget.selectedProfileKey,
                onChanged: (value) { if (value != null) widget.onProfileSelected(value); },
                title: Text(widget.profileBox.get(key)!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(widget.profileBox.get(key)!.isVerified ? 'Verified catalog profile' : 'Unverified manual profile'),
              ),
            ListTile(onTap: _createManualProfile, leading: const Icon(Icons.add_rounded), title: const Text('Add unverified bike', style: TextStyle(fontWeight: FontWeight.w800))),
          ])),
          TextButton.icon(
            onPressed: _copyBikeRequest,
            icon: const Icon(Icons.outgoing_mail),
            label: const Text('Request a missing bike on GitHub'),
          ),
          TextButton.icon(
            onPressed: _refreshCatalog,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh verified bike catalog'),
          ),
          const SizedBox(height: 20),
          Text('RIDER PROFILE', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.person_rounded),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _riderWeightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)', border: InputBorder.none),
                  onSubmitted: (_) => _saveRiderWeight(),
                )),
                IconButton(onPressed: _saveRiderWeight, icon: const Icon(Icons.check_rounded), tooltip: 'Save weight'),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          Text('BIKE MODEL', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            'Vehicle specs come from the catalog, not manual entry — '
            'weight/voltage/capacity are manufacturer facts.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          for (final brand in grouped.keys) ...[
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                    child: Text(brand.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                  ),
                  for (final entry in grouped[brand]!)
                    RadioListTile<String>(
                      value: entry.displayName,
                      groupValue: widget.profile.name,
                      onChanged: (_) => _selectVehicle(entry),
                      title: Text(entry.model, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${entry.systemVoltage.toStringAsFixed(0)}V · ${entry.batteryAh.toStringAsFixed(0)}Ah · ${entry.topSpeedKmh.toStringAsFixed(0)} km/h'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          Text('APP UPDATES', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(child: ListTile(
            onTap: _checkForUpdate,
            leading: const Icon(Icons.system_update_rounded),
            title: const Text('Check GitHub releases', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('View the latest release notes and update availability.'),
            trailing: const Icon(Icons.chevron_right_rounded),
          )),
          TextButton.icon(
            onPressed: _shareCalibration,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Export anonymous calibration data'),
          ),
        ],
      ),
    );
  }
}
