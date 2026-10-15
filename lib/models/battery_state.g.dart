// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'battery_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BatteryStateAdapter extends TypeAdapter<BatteryState> {
  @override
  final int typeId = 8;

  @override
  BatteryState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BatteryState(
      profileKey: fields[0] as String,
      remainingWh: fields[1] as double,
      lastUpdatedMs: fields[2] as int,
      lastFullChargeMs: fields[3] as int?,
      confidence: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BatteryState obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.profileKey)
      ..writeByte(1)
      ..write(obj.remainingWh)
      ..writeByte(2)
      ..write(obj.lastUpdatedMs)
      ..writeByte(3)
      ..write(obj.lastFullChargeMs)
      ..writeByte(4)
      ..write(obj.confidence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
