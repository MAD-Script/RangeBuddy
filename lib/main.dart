import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'models/vehicle_profile.dart';
import 'models/trip_sample.dart';
import 'models/trip_metadata.dart';
import 'models/bar_drop_event.dart';
import 'models/vehicle_alert_event.dart';
import 'models/passenger.dart';
import 'services/range_engine.dart';
import 'services/trip_logger.dart';
import 'services/trip_foreground_task.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/active_trip_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/vehicle_setup_screen.dart';

late Box<VehicleProfile> profileBox;
late Box<TripSample> sampleBox;
late Box<TripMetadata> metadataBox;
late Box<BarDropEvent> barDropBox;
late Box<VehicleAlertEvent> alertBox;
late Box<Passenger> passengerBox;
late Directory tileCacheDir;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(VehicleProfileAdapter());
  Hive.registerAdapter(TripSampleAdapter());
  Hive.registerAdapter(ChargeStateTypeAdapter());
  Hive.registerAdapter(TripMetadataAdapter());
  Hive.registerAdapter(BarDropEventAdapter());
  Hive.registerAdapter(VehicleAlertTypeAdapter());
  Hive.registerAdapter(VehicleAlertEventAdapter());
  Hive.registerAdapter(PassengerAdapter());

  profileBox = await Hive.openBox<VehicleProfile>('vehicle_profile');
  sampleBox = await Hive.openBox<TripSample>('trip_samples');
  metadataBox = await Hive.openBox<TripMetadata>('trip_metadata');
  barDropBox = await Hive.openBox<BarDropEvent>('bar_drop_events');
  alertBox = await Hive.openBox<VehicleAlertEvent>('alert_events');
  passengerBox = await Hive.openBox<Passenger>('passengers');

  if (profileBox.isEmpty) {
    await profileBox.add(VehicleProfile()); // F52 defaults
  }

  final docsDir = await getApplicationDocumentsDirectory();
  tileCacheDir = docsDir; // OfflineFirstTileProvider nests under map_tiles/

  // Required before runApp() for the foreground service's isolate
  // communication to work (see trip_foreground_task.dart).
  FlutterForegroundTask.initCommunicationPort();
  initTripForegroundTask();

  runApp(const EvRangeTrackerApp());
}

class EvRangeTrackerApp extends StatelessWidget {
  const EvRangeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Range Tracker',
      theme: buildAppTheme(null, Brightness.light),
      darkTheme: buildAppTheme(null, Brightness.dark),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _ActiveRideParams {
  final String tripId;
  final double riderWeightKg;
  final double passengerWeightKg;
  final double totalMassKg;

  const _ActiveRideParams({
    required this.tripId,
    required this.riderWeightKg,
    required this.passengerWeightKg,
    required this.totalMassKg,
  });
}

class _RootShellState extends State<RootShell> {
  int _tabIndex = 0;
  double _selectedPassengerWeightKg = 0;
  _ActiveRideParams? _activeRide;
  late final VehicleProfile _profile = profileBox.values.first;
  late final RangeEngine _engine = RangeEngine(profile: _profile);
  late final TripLogger _logger = TripLogger(
    sampleBox: sampleBox,
    metadataBox: metadataBox,
    barDropBox: barDropBox,
    alertBox: alertBox,
  );

  Future<void> _startRide() async {
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalMassKg = _profile.vehicleWeightKg +
        _profile.defaultRiderWeightKg +
        _selectedPassengerWeightKg;
    _activeRide = _ActiveRideParams(
      tripId: tripId,
      riderWeightKg: _profile.defaultRiderWeightKg,
      passengerWeightKg: _selectedPassengerWeightKg,
      totalMassKg: totalMassKg,
    );
    await _openActiveTripScreen();
  }

  // Used both for starting fresh (from Start Ride) and for resuming a
  // ride already in progress (from Home's "Active Ride" tile) — which
  // path applies is decided inside ActiveTripScreen itself, based on
  // whether TripLogger says this tripId is already logging.
  Future<void> _openActiveTripScreen() async {
    final ride = _activeRide;
    if (ride == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(
          engine: _engine,
          logger: _logger,
          tripId: ride.tripId,
          riderWeightKg: ride.riderWeightKg,
          passengerWeightKg: ride.passengerWeightKg,
          totalMassKg: ride.totalMassKg,
          tileCacheDir: tileCacheDir,
          metadataBox: metadataBox,
        ),
      ),
    );
    // If the ride ended (End Ride was tapped) while we were there,
    // clear it so Home stops offering to resume a trip that's over.
    if (!_logger.isLogging) {
      _activeRide = null;
    }
    setState(() {}); // refresh Home's gauge/active-ride tile
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        engine: _engine,
        profile: _profile,
        passengerBox: passengerBox,
        onStartRide: _startRide,
        onPassengerWeightChanged: (kg) => _selectedPassengerWeightKg = kg,
        isRideActive: _activeRide != null,
        onResumeRide: _openActiveTripScreen,
      ),
      TripHistoryScreen(
        metadataBox: metadataBox,
        sampleBox: sampleBox,
        barDropBox: barDropBox,
        alertBox: alertBox,
        logger: _logger,
        tileCacheDir: tileCacheDir,
      ),
      VehicleSetupScreen(profile: _profile, tileCacheDir: tileCacheDir),
    ];

    return Scaffold(
      body: screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
