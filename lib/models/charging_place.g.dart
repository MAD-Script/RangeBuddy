// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'charging_place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChargingPlaceAdapter extends TypeAdapter<ChargingPlace> {
  @override
  final int typeId = 11;

  @override
  ChargingPlace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChargingPlace(
      profileKey: fields[0] as String,
      name: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      isFree: fields[4] as bool,
      chargerName: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChargingPlace obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.profileKey)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.isFree)
      ..writeByte(5)
      ..write(obj.chargerName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChargingPlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
