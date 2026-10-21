/// Static bike model specs — NOT user-editable, since weight/voltage/
/// capacity are manufacturer facts, not personal preferences. Users
/// pick a model from this catalog in Settings; only rider weight and
/// the learned calibration constants (in VehicleProfile) stay editable.
///
/// Add more entries here as you support more bikes. Grouped by brand
/// for the picker UI.
class VehicleCatalogEntry {
  final String id;
  final String brand;
  final String model;
  final double systemVoltage;
  final double batteryAh;
  final double motorWattPeak;
  final double vehicleWeightKg;
  final double topSpeedKmh;
  final double ratedRangeKm;

  const VehicleCatalogEntry({
    required this.id,
    required this.brand,
    required this.model,
    required this.systemVoltage,
    required this.batteryAh,
    required this.motorWattPeak,
    required this.vehicleWeightKg,
    required this.topSpeedKmh,
    required this.ratedRangeKm,
  });

  String get displayName => '$brand $model';

  /// A sensible first estimate until the rider's own calibration data takes
  /// precedence. Manufacturer range figures are optimistic, so calibration
  /// remains the source of truth for RangeBuddy predictions.
  double get nominalWhPerKm => (systemVoltage * batteryAh) / ratedRangeKm;

  factory VehicleCatalogEntry.fromJson(Map<String, dynamic> json) =>
      VehicleCatalogEntry(
        id: json['id'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        systemVoltage: (json['system_voltage'] as num).toDouble(),
        batteryAh: (json['battery_ah'] as num).toDouble(),
        motorWattPeak: (json['motor_watt_peak'] as num).toDouble(),
        vehicleWeightKg: (json['vehicle_weight_kg'] as num).toDouble(),
        topSpeedKmh: (json['top_speed_kmh'] as num).toDouble(),
        ratedRangeKm: (json['rated_range_km'] as num).toDouble(),
      );
}

const List<VehicleCatalogEntry> vehicleCatalog = [
  VehicleCatalogEntry(
    id: 'tailg-f52-red-rabbit',
    brand: 'TailG',
    model: 'F52 Red Rabbit',
    systemVoltage: 72.0,
    batteryAh: 23.0,
    motorWattPeak: 1200.0,
    vehicleWeightKg: 104.0, // midpoint of manufacturer's 103-105kg spec
    topSpeedKmh: 55.0, // rated sport-mode speed; gauge displays to 60 km/h
    ratedRangeKm: 90.0,
  ),
  // Specifications below are from TAILG Bangladesh's published model pages.
  // Kerb weight is not listed for every model; those conservative operational
  // estimates only seed the physics model and are refined by calibration.
  VehicleCatalogEntry(
    id: 'tailg-jaguar-t72l',
    brand: 'TailG',
    model: 'Jaguar T72L',
    systemVoltage: 76.0,
    batteryAh: 32.0,
    motorWattPeak: 2000.0,
    vehicleWeightKg: 110.0,
    topSpeedKmh: 70.0,
    ratedRangeKm: 110.0,
  ),
  VehicleCatalogEntry(
    id: 'tailg-leopard-f72',
    brand: 'TailG',
    model: 'Leopard F72',
    systemVoltage: 96.0,
    batteryAh: 52.0,
    motorWattPeak: 3000.0,
    vehicleWeightKg: 180.0,
    topSpeedKmh: 70.0,
    ratedRangeKm: 180.0,
  ),
  VehicleCatalogEntry(
    id: 'tailg-rhino-t53',
    brand: 'TailG',
    model: 'Rhino T53',
    systemVoltage: 72.0,
    batteryAh: 35.0,
    motorWattPeak: 1500.0,
    vehicleWeightKg: 108.0,
    topSpeedKmh: 60.0,
    ratedRangeKm: 120.0,
  ),
  VehicleCatalogEntry(
    id: 'tailg-saibei-f71',
    brand: 'TailG',
    model: 'Saibei F71',
    systemVoltage: 72.0,
    batteryAh: 35.0,
    motorWattPeak: 1500.0,
    vehicleWeightKg: 105.0,
    topSpeedKmh: 55.0,
    ratedRangeKm: 120.0,
  ),
  VehicleCatalogEntry(
    id: 'tailg-orca-f50',
    brand: 'TailG',
    model: 'Orca F50',
    systemVoltage: 60.0,
    batteryAh: 26.0,
    motorWattPeak: 1000.0,
    vehicleWeightKg: 95.0,
    topSpeedKmh: 50.0,
    ratedRangeKm: 85.0,
  ),
];

/// Groups the catalog by brand for a sectioned picker UI.
Map<String, List<VehicleCatalogEntry>> groupCatalogByBrand(
    [Iterable<VehicleCatalogEntry> entries = vehicleCatalog]) {
  final map = <String, List<VehicleCatalogEntry>>{};
  for (final entry in entries) {
    map.putIfAbsent(entry.brand, () => []).add(entry);
  }
  return map;
}
