import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/passenger.dart';
import '../models/vehicle_profile.dart';
import '../services/range_engine.dart';

class HomeScreen extends StatefulWidget {
  final RangeEngine engine;
  final VehicleProfile profile;
  final Box<Passenger> passengerBox;
  final VoidCallback onStartRide;
  final bool isRideActive;
  final VoidCallback onResumeRide;
  final VoidCallback onOpenBatteryHealth;

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
    required this.onOpenBatteryHealth,
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
            const Text('RangeBuddy', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              widget.profile.name,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TopEstimate(
                      label: 'ESTIMATED RANGE',
                      value: rangeKm.toStringAsFixed(0),
                      unit: 'km',
                    ),
                  ),
                  Container(width: 1, height: 66, color: scheme.outlineVariant),
                  Expanded(
                    child: _TopEstimate(
                      label: 'ESTIMATED CHARGE LEFT',
                      value: batteryPercent.toStringAsFixed(0),
                      unit: '%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  !widget.profile.isVerified
                      ? 'Unverified bike profile — calibrate from real charges and rides'
                      : batteryPercent < 20
                          ? 'Charge soon for a confident trip'
                          : 'Ready for the road',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
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
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  onTap: widget.onOpenBatteryHealth,
                  leading: Icon(Icons.favorite_rounded, color: scheme.primary),
                  title: const Text('Battery health', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Estimated usable battery capacity'),
                  trailing: Text(
                    '${(widget.profile.socHealthFactor * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
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

class _TopEstimate extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _TopEstimate({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.15, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        RichText(text: TextSpan(style: TextStyle(color: scheme.onSurface), children: [
          TextSpan(text: value, style: const TextStyle(fontSize: 52, height: .95, fontWeight: FontWeight.w900, letterSpacing: -2)),
          TextSpan(text: unit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
        ])),
      ],
    );
  }
}

class _EnergySummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EnergySummary({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
