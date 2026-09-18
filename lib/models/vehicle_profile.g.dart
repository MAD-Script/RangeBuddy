// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehicleProfileAdapter extends TypeAdapter<VehicleProfile> {
  @override
  final int typeId = 0;

  @override
  VehicleProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VehicleProfile(
      name: fields[0] as String,
      systemVoltage: fields[1] as double,
      batteryAh: fields[2] as double,
      motorWattPeak: fields[3] as double,
      baseWhPerKm: fields[4] as double,
      crr: fields[5] as double,
      dragCoefficientArea: fields[6] as double,
      efficiency: fields[7] as double,
      socHealthFactor: fields[8] as double,
      vehicleWeightKg: fields[9] as double,
      defaultRiderWeightKg: fields[10] as double,
      congestionOverheadWhPerKm: fields[11] as double,
      congestionSpeedThresholdKmh: fields[12] as double,
      topSpeedKmh: fields[13] as double,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleProfile obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.systemVoltage)
      ..writeByte(2)
      ..write(obj.batteryAh)
      ..writeByte(3)
      ..write(obj.motorWattPeak)
      ..writeByte(4)
      ..write(obj.baseWhPerKm)
      ..writeByte(5)
      ..write(obj.crr)
      ..writeByte(6)
      ..write(obj.dragCoefficientArea)
      ..writeByte(7)
      ..write(obj.efficiency)
      ..writeByte(8)
      ..write(obj.socHealthFactor)
      ..writeByte(9)
      ..write(obj.vehicleWeightKg)
      ..writeByte(10)
      ..write(obj.defaultRiderWeightKg)
      ..writeByte(11)
      ..write(obj.congestionOverheadWhPerKm)
      ..writeByte(12)
      ..write(obj.congestionSpeedThresholdKmh)
      ..writeByte(13)
      ..write(obj.topSpeedKmh);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
