// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripMetadataAdapter extends TypeAdapter<TripMetadata> {
  @override
  final int typeId = 3;

  @override
  TripMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripMetadata(
      tripId: fields[0] as String,
      startTimestampMs: fields[1] as int,
      riderWeightKg: fields[3] as double,
      passengerWeightKg: fields[4] as double,
      startChargeType: fields[5] as ChargeStateType,
      startBarLevel: fields[6] as int?,
      endTimestampMs: fields[2] as int?,
      endChargeType: fields[7] as ChargeStateType,
      endBarLevel: fields[8] as int?,
      notes: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TripMetadata obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.startTimestampMs)
      ..writeByte(2)
      ..write(obj.endTimestampMs)
      ..writeByte(3)
      ..write(obj.riderWeightKg)
      ..writeByte(4)
      ..write(obj.passengerWeightKg)
      ..writeByte(5)
      ..write(obj.startChargeType)
      ..writeByte(6)
      ..write(obj.startBarLevel)
      ..writeByte(7)
      ..write(obj.endChargeType)
      ..writeByte(8)
      ..write(obj.endBarLevel)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChargeStateTypeAdapter extends TypeAdapter<ChargeStateType> {
  @override
  final int typeId = 2;

  @override
  ChargeStateType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChargeStateType.fullCharge;
      case 1:
        return ChargeStateType.barLevel;
      case 2:
        return ChargeStateType.unknown;
      default:
        return ChargeStateType.fullCharge;
    }
  }

  @override
  void write(BinaryWriter writer, ChargeStateType obj) {
    switch (obj) {
      case ChargeStateType.fullCharge:
        writer.writeByte(0);
        break;
      case ChargeStateType.barLevel:
        writer.writeByte(1);
        break;
      case ChargeStateType.unknown:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChargeStateTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
