// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'charger_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChargerProfileAdapter extends TypeAdapter<ChargerProfile> {
  @override
  final int typeId = 9;

  @override
  ChargerProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChargerProfile(
      profileKey: fields[0] as String,
      name: fields[1] as String,
      wattage: fields[2] as double,
      efficiency: fields[3] as double,
      isDefault: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChargerProfile obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.profileKey)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.wattage)
      ..writeByte(3)
      ..write(obj.efficiency)
      ..writeByte(4)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChargerProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
