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
import 'models/battery_state.dart';
import 'models/charger_profile.dart';
import 'models/charge_session.dart';
import 'models/charging_place.dart';
import 'services/range_engine.dart';
import 'services/trip_logger.dart';
import 'services/trip_foreground_task.dart';
import 'services/github_release_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/active_trip_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/vehicle_setup_screen.dart';
import 'screens/charging_screen.dart';

late Box<VehicleProfile> profileBox;
late Box<TripSample> sampleBox;
late Box<TripMetadata> metadataBox;
late Box<BarDropEvent> barDropBox;
late Box<VehicleAlertEvent> alertBox;
late Box<Passenger> passengerBox;
late Box<BatteryState> batteryStateBox;
late Box<ChargerProfile> chargerBox;
late Box<ChargeSession> chargeSessionBox;
late Box<ChargingPlace> chargingPlaceBox;
late Box<String> appSettingsBox;
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
  Hive.registerAdapter(BatteryStateAdapter());
  Hive.registerAdapter(ChargerProfileAdapter());
  Hive.registerAdapter(ChargeSessionAdapter());
  Hive.registerAdapter(ChargingPlaceAdapter());

  profileBox = await Hive.openBox<VehicleProfile>('vehicle_profile');
  sampleBox = await Hive.openBox<TripSample>('trip_samples');
  metadataBox = await Hive.openBox<TripMetadata>('trip_metadata');
  barDropBox = await Hive.openBox<BarDropEvent>('bar_drop_events');
  alertBox = await Hive.openBox<VehicleAlertEvent>('alert_events');
  passengerBox = await Hive.openBox<Passenger>('passengers');
  batteryStateBox = await Hive.openBox<BatteryState>('battery_states');
  chargerBox = await Hive.openBox<ChargerProfile>('chargers');
  chargeSessionBox = await Hive.openBox<ChargeSession>('charge_sessions');
  chargingPlaceBox = await Hive.openBox<ChargingPlace>('charging_places');
  appSettingsBox = await Hive.openBox<String>('app_settings');

  if (profileBox.isEmpty) {
    await profileBox.add(VehicleProfile()); // F52 defaults
  } else {
    // Existing installs used the older 50 km/h catalog value. Bring the
    // bundled F52 profile in line with its 55 km/h rated sport specification.
    final savedProfile = profileBox.values.first;
    if (savedProfile.name == 'TailG F52 Red Rabbit' &&
        savedProfile.topSpeedKmh < 55) {
      savedProfile.topSpeedKmh = 55;
      await savedProfile.save();
    }
  }

  final docsDir = await getApplicationDocumentsDirectory();
  // Retained for route/map widgets while offline map downloads are on hold.
  tileCacheDir = docsDir;

  // Required before runApp() for the foreground service's isolate
  // communication to work (see trip_foreground_task.dart).
  FlutterForegroundTask.initCommunicationPort();
  initTripForegroundTask();

  runApp(const RangeBuddyApp());
}

class RangeBuddyApp extends StatelessWidget {
  const RangeBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RangeBuddy',
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
  final bool isCalibrationRide;

  const _ActiveRideParams({
    required this.tripId,
    required this.riderWeightKg,
    required this.passengerWeightKg,
    required this.totalMassKg,
    this.isCalibrationRide = false,
  });
}

class _RootShellState extends State<RootShell> {
  int _tabIndex = 0;
  double _selectedPassengerWeightKg = 0;
  _ActiveRideParams? _activeRide;
  late VehicleProfile _profile;
  late RangeEngine _engine;
  late String _profileKey;
  late final TripLogger _logger = TripLogger(
    sampleBox: sampleBox,
    metadataBox: metadataBox,
    barDropBox: barDropBox,
    alertBox: alertBox,
  );

  @override
  void initState() {
    super.initState();
    _loadSelectedProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdateOnOpen());
  }

  Future<void> _checkUpdateOnOpen() async {
    final today = DateTime.now();
    final key = 'update_prompt_${today.year}${today.month}${today.day}';
    if (appSettingsBox.get(key) == 'seen') return;
    try {
      final release = await GitHubReleaseService().latestRelease();
      if (!mounted || release == null || !release.isNewerThanInstalled) return;
      await appSettingsBox.put(key, 'seen');
      await _showReleaseNotes(release);
    } catch (_) {
      // Update checks must never block an offline-first ride tracker.
    }
  }

  Future<void> _showReleaseNotes(GitHubRelease release) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('New update available · v${release.version}'),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(release.notes))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        if (release.apkUrl != null) FilledButton(onPressed: () async { Navigator.pop(context); await AndroidUpdateInstaller().downloadAndInstall(release); }, child: const Text('Update now')),
      ],
    ),
  );

  void _loadSelectedProfile([String? requestedKey]) {
    final selectedKey = requestedKey ??
        appSettingsBox.get('selected_profile_key') ??
        profileBox.keys.first.toString();
    final hiveKey = profileBox.keys.firstWhere(
      (key) => key.toString() == selectedKey,
      orElse: () => profileBox.keys.first,
    );
    _profileKey = hiveKey.toString();
    _profile = profileBox.get(hiveKey)!;
    final state = batteryStateBox.get(_profileKey);
    _engine = RangeEngine(profile: _profile, startingWh: state?.remainingWh);
    appSettingsBox.put('selected_profile_key', _profileKey);
  }

  void _persistBattery({bool fullCharge = false}) {
    final previous = batteryStateBox.get(_profileKey);
    batteryStateBox.put(
      _profileKey,
      BatteryState(
        profileKey: _profileKey,
        remainingWh: _engine.eRemainingWh,
        lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
        lastFullChargeMs: fullCharge
            ? DateTime.now().millisecondsSinceEpoch
            : previous?.lastFullChargeMs,
        confidence: fullCharge ? .8 : previous?.confidence ?? .45,
      ),
    );
  }

  Future<void> _recordFullCharge() async {
    final startPercent = _engine.batteryPercent();
    final beforeWh = _engine.eRemainingWh;
    _engine.resetToFull();
    final recoveredWh = _engine.eRemainingWh - beforeWh;
    await chargeSessionBox.add(ChargeSession(
      profileKey: _profileKey,
      chargerName: 'Full charge',
      hours: 7.5,
      recoveredWh: recoveredWh,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      startPercent: startPercent,
      endPercent: 100,
    ));
    _persistBattery(fullCharge: true);
    if (mounted) setState(() {});
  }

  void _switchProfile(String key) {
    setState(() => _loadSelectedProfile(key));
  }

  Future<void> _startRide({bool calibration = false}) async {
    final calibrationMode = calibration ||
        appSettingsBox.get('calibration_mode_${_profileKey}') == 'true';
    if (calibrationMode && !calibration && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start calibration ride?'),
          content: const Text('Start only from a confirmed full charge. Do not log a charge during this ride. End calibration with Battery drained when the bike is crawling at about 5–10 km/h.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start calibration')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalMassKg = _profile.vehicleWeightKg +
        _profile.defaultRiderWeightKg +
        _selectedPassengerWeightKg;
    _activeRide = _ActiveRideParams(
      tripId: tripId,
      riderWeightKg: _profile.defaultRiderWeightKg,
      passengerWeightKg: _selectedPassengerWeightKg,
      totalMassKg: totalMassKg,
      isCalibrationRide: calibrationMode,
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
          onBatteryChanged: _persistBattery,
          chargingPlaceBox: chargingPlaceBox,
          profileKey: _profileKey,
          isCalibrationRide: ride.isCalibrationRide,
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
        onOpenBatteryHealth: () => setState(() => _tabIndex = 3),
      ),
      TripHistoryScreen(
        metadataBox: metadataBox,
        sampleBox: sampleBox,
        barDropBox: barDropBox,
        alertBox: alertBox,
        logger: _logger,
        tileCacheDir: tileCacheDir,
      ),
      ChargingScreen(
        profile: _profile,
        profileKey: _profileKey,
        engine: _engine,
        chargerBox: chargerBox,
        sessionBox: chargeSessionBox,
        placeBox: chargingPlaceBox,
        onBatteryChanged: _persistBattery,
        onFullCharge: _recordFullCharge,
        isCalibrationActive: _activeRide?.isCalibrationRide == true && _logger.isLogging,
        tileCacheDir: tileCacheDir,
      ),
      VehicleSetupScreen(
        profile: _profile,
        profileBox: profileBox,
        selectedProfileKey: _profileKey,
        onProfileSelected: _switchProfile,
        appSettingsBox: appSettingsBox,
        profileKey: _profileKey,
        batteryStateBox: batteryStateBox,
        chargeSessionBox: chargeSessionBox,
        onStartCalibration: () => _startRide(calibration: true),
        onConfirmFullCharge: () { _recordFullCharge(); },
        tileCacheDir: tileCacheDir,
      ),
    ];

    return Scaffold(
      body: screens[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), label: 'Charge'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
