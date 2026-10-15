// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'charge_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChargeSessionAdapter extends TypeAdapter<ChargeSession> {
  @override
  final int typeId = 10;

  @override
  ChargeSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChargeSession(
      profileKey: fields[0] as String,
      chargerName: fields[1] as String,
      hours: fields[2] as double,
      recoveredWh: fields[3] as double,
      timestampMs: fields[4] as int,
      placeName: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChargeSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.profileKey)
      ..writeByte(1)
      ..write(obj.chargerName)
      ..writeByte(2)
      ..write(obj.hours)
      ..writeByte(3)
      ..write(obj.recoveredWh)
      ..writeByte(4)
      ..write(obj.timestampMs)
      ..writeByte(5)
      ..write(obj.placeName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChargeSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
