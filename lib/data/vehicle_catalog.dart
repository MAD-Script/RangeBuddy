/// Static bike model specs — NOT user-editable, since weight/voltage/
/// capacity are manufacturer facts, not personal preferences. Users
/// pick a model from this catalog in Settings; only rider weight and
/// the learned calibration constants (in VehicleProfile) stay editable.
///
/// Add more entries here as you support more bikes. Grouped by brand
/// for the picker UI.
class VehicleCatalogEntry {
  final String brand;
  final String model;
  final double systemVoltage;
  final double batteryAh;
  final double motorWattPeak;
  final double vehicleWeightKg;
  final double topSpeedKmh;

  const VehicleCatalogEntry({
    required this.brand,
    required this.model,
    required this.systemVoltage,
    required this.batteryAh,
    required this.motorWattPeak,
    required this.vehicleWeightKg,
    required this.topSpeedKmh,
  });

  String get displayName => '$brand $model';
}

const List<VehicleCatalogEntry> vehicleCatalog = [
  VehicleCatalogEntry(
    brand: 'TailG',
    model: 'F52 Red Rabbit',
    systemVoltage: 72.0,
    batteryAh: 23.0,
    motorWattPeak: 1200.0,
    vehicleWeightKg: 104.0, // midpoint of manufacturer's 103-105kg spec
    topSpeedKmh: 50.0, // full-throttle spec, not your usual eco-mode cap
  ),
  // Add more models here as needed, grouped by brand in the picker
  // since it reads them in catalog order.
];

/// Groups the catalog by brand for a sectioned picker UI.
Map<String, List<VehicleCatalogEntry>> groupCatalogByBrand() {
  final map = <String, List<VehicleCatalogEntry>>{};
  for (final entry in vehicleCatalog) {
    map.putIfAbsent(entry.brand, () => []).add(entry);
  }
  return map;
}
