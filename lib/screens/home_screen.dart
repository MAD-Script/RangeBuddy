import 'package:flutter/material.dart';
import '../models/passenger.dart';
import '../models/vehicle_profile.dart';
import '../services/range_engine.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/stat_tile.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeScreen extends StatefulWidget {
  final RangeEngine engine;
  final VehicleProfile profile;
  final Box<Passenger> passengerBox;
  final VoidCallback onStartRide;

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

    return Scaffold(
      appBar: AppBar(title: Text(widget.profile.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: BatteryTankGauge(
                    percent: engine.batteryPercent(),
                    rangeLabel: '~${rangeKm.toStringAsFixed(0)} km remaining',
                    isEstimateUncertain: engine.batteryPercent() < 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'System',
                      value: '${widget.profile.systemVoltage.toStringAsFixed(0)}V',
                      icon: Icons.bolt_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Capacity',
                      value: '${widget.profile.batteryAh.toStringAsFixed(0)}Ah',
                      icon: Icons.battery_full,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Health',
                      value:
                          '${(widget.profile.socHealthFactor * 100).toStringAsFixed(0)}%',
                      icon: Icons.favorite_border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Riding with', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              // Only one of these can be active at a time — the bike
              // seats 2 total (you + one passenger), so selecting one
              // toggles the others off automatically.
              ValueListenableBuilder(
                valueListenable: widget.passengerBox.listenable(),
                builder: (context, Box<Passenger> box, _) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
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
                  );
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: widget.onStartRide,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Ride'),
              ),
              const SizedBox(height: 12),
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
