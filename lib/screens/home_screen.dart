import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/passenger.dart';
import '../models/vehicle_profile.dart';
import '../services/range_engine.dart';
import '../widgets/battery_gauge.dart';

class HomeScreen extends StatefulWidget {
  final RangeEngine engine;
  final VehicleProfile profile;
  final Box<Passenger> passengerBox;
  final VoidCallback onStartRide;
  final bool isRideActive;
  final VoidCallback onResumeRide;

  /// Called whenever the passenger selection changes, so the caller
  /// always has the current passenger weight ready the instant
  /// "Start Ride" is pressed — no extra plumbing needed at that point.
  final ValueChanged<double> onPassengerWeightChanged;

  const HomeScreen({
    super.key,
    required this.engine,
    required this.profile,
    required this.passengerBox,
    required this.onStartRide,
    required this.onPassengerWeightChanged,
    required this.isRideActive,
    required this.onResumeRide,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 'solo', a Hive key (as string) for a saved passenger, or 'temporary'.
class _PassengerSelection {
  static const solo = 'solo';
  static const temporary = 'temporary';
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedKey = _PassengerSelection.solo;
  double _temporaryWeightKg = 0;

  void _select(String key, double weightKg) {
    setState(() => _selectedKey = key);
    widget.onPassengerWeightChanged(weightKg);
  }

  Future<void> _selectTemporary() async {
    final controller = TextEditingController(
      text: _temporaryWeightKg > 0 ? _temporaryWeightKg.toStringAsFixed(0) : '',
    );
    final weight = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temporary passenger weight'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (weight != null && weight > 0) {
      _temporaryWeightKg = weight;
      _select(_PassengerSelection.temporary, weight);
    }
  }

  Future<void> _addSavedPassenger() async {
    final nameController = TextEditingController();
    final weightController = TextEditingController();
    final result = await showDialog<Passenger>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add passenger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final weight = double.tryParse(weightController.text);
              if (nameController.text.trim().isEmpty || weight == null) return;
              Navigator.pop(
                context,
                Passenger(name: nameController.text.trim(), weightKg: weight),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      await widget.passengerBox.add(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final rangeKm = engine.estimatedRangeKmBaseline();
    final scheme = Theme.of(context).colorScheme;
    final batteryPercent = engine.batteryPercent();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.profile.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('RANGE TRACKER', style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(color: const Color(0xFF35A982), shape: BoxShape.circle),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'ESTIMATED RANGE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: scheme.onSurface),
                    children: [
                      TextSpan(
                        text: rangeKm.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 76, height: .95, fontWeight: FontWeight.w900, letterSpacing: -3),
                      ),
                      TextSpan(
                        text: ' km',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  batteryPercent < 20 ? 'Charge soon for a confident trip' : 'Ready for the road',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: BatteryTankGauge(
                    percent: batteryPercent,
                    rangeLabel: '${batteryPercent.toStringAsFixed(0)}% charge available',
                    isEstimateUncertain: batteryPercent < 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('VEHICLE SNAPSHOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'SYSTEM',
                      value: '${widget.profile.systemVoltage.toStringAsFixed(0)}V',
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'CAPACITY',
                      value: '${widget.profile.batteryAh.toStringAsFixed(0)}Ah',
                      icon: Icons.battery_charging_full_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'HEALTH',
                      value:
                          '${(widget.profile.socHealthFactor * 100).toStringAsFixed(0)}%',
                      icon: Icons.favorite_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text('RIDE SETUP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              // Only one of these can be active at a time — the bike
              // seats 2 total (you + one passenger), so selecting one
              // toggles the others off automatically.
              ValueListenableBuilder(
                valueListenable: widget.passengerBox.listenable(),
                builder: (context, Box<Passenger> box, _) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.person_rounded, size: 17),
                            label: const Text('Solo'),
                            selected: _selectedKey == _PassengerSelection.solo,
                            onSelected: (_) => _select(_PassengerSelection.solo, 0),
                          ),
                      for (final key in box.keys)
                        ChoiceChip(
                          label: Text(box.get(key)!.name),
                          selected: _selectedKey == key.toString(),
                          onSelected: (_) =>
                              _select(key.toString(), box.get(key)!.weightKg),
                        ),
                      ChoiceChip(
                        label: Text(
                          _selectedKey == _PassengerSelection.temporary &&
                                  _temporaryWeightKg > 0
                              ? 'Temporary (${_temporaryWeightKg.toStringAsFixed(0)}kg)'
                              : 'Temporary…',
                        ),
                        selected: _selectedKey == _PassengerSelection.temporary,
                        onSelected: (_) => _selectTemporary(),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        onPressed: _addSavedPassenger,
                      ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: widget.isRideActive ? null : widget.onStartRide,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('START RIDE'),
              ),
              if (widget.isRideActive) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    onTap: widget.onResumeRide,
                    leading: Icon(
                      Icons.electric_bike,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    title: Text(
                      'Ride in progress',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Tap to return to your active ride',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => setState(engine.resetToFull),
                icon: const Icon(Icons.battery_charging_full),
                label: const Text('Fully Charged'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 9, letterSpacing: .8, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
