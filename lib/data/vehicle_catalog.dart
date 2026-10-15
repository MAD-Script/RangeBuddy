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

  const VehicleCatalogEntry({
    required this.id,
    required this.brand,
    required this.model,
    required this.systemVoltage,
    required this.batteryAh,
    required this.motorWattPeak,
    required this.vehicleWeightKg,
    required this.topSpeedKmh,
  });

  String get displayName => '$brand $model';

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
  ),
  // Add more models here as needed, grouped by brand in the picker
  // since it reads them in catalog order.
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
