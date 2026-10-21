import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/battery_state.dart';
import '../models/charge_session.dart';
import '../models/vehicle_profile.dart';

class BatteryHealthScreen extends StatelessWidget {
  final VehicleProfile profile;
  final String profileKey;
  final Box<BatteryState> batteryStates;
  final Box<ChargeSession> sessions;

  const BatteryHealthScreen({super.key, required this.profile, required this.profileKey, required this.batteryStates, required this.sessions});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Battery health', style: TextStyle(fontWeight: FontWeight.w800))),
    body: AnimatedBuilder(
      animation: Listenable.merge([batteryStates.listenable(), sessions.listenable()]),
      builder: (context, _) {
        final state = batteryStates.get(profileKey);
        final relevant = sessions.values.where((s) => s.profileKey == profileKey).toList();
        final health = profile.socHealthFactor * 100;
        final estimatedWh = profile.totalEnergyWh() * profile.socHealthFactor;
        final lastFull = state?.lastFullChargeMs == null ? 'No confirmed full charge yet' : _date(state!.lastFullChargeMs!);
        return ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Battery health estimates usable capacity compared with the bike’s design capacity. A completed calibration is the highest-confidence measurement.', style: TextStyle(height: 1.35)),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Battery health', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: health / 100, minHeight: 10),
            const SizedBox(height: 10),
            Text('${health.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            Text('Estimated capacity ${estimatedWh.toStringAsFixed(0)} Wh of ${profile.totalEnergyWh().toStringAsFixed(0)} Wh design capacity'),
          ]))),
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const Icon(Icons.battery_charging_full_rounded), title: const Text('Last full charge'), subtitle: Text(lastFull))),
          Card(child: ListTile(leading: const Icon(Icons.insights_rounded), title: const Text('${relevant.length} charge sessions recorded'), subtitle: Text('${relevant.fold<double>(0, (sum, item) => sum + item.recoveredWh).toStringAsFixed(0)} Wh recovered in total'))),
          const SizedBox(height: 18),
          Text('HOW TO CALIBRATE', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('1. Confirm a full charge.\n2. Enable Calibration mode in Settings.\n3. Ride normally; passengers are allowed.\n4. Log Audible warning, Critical and finally Battery drained when the bike is crawling at about 5–10 km/h.\n5. Do not log a charge before Battery drained.')),
        ]);
      },
    ),
  );

  String _date(int ms) { final d = DateTime.fromMillisecondsSinceEpoch(ms); return '${d.day}/${d.month}/${d.year}'; }
}
