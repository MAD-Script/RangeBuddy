// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_sample.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripSampleAdapter extends TypeAdapter<TripSample> {
  @override
  final int typeId = 1;

  @override
  TripSample read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripSample(
      tripId: fields[0] as String,
      timestampMs: fields[1] as int,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      gpsSpeedKmh: fields[4] as double,
      accuracyM: fields[6] as double,
      altitudeM: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, TripSample obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.timestampMs)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.gpsSpeedKmh)
      ..writeByte(5)
      ..write(obj.altitudeM)
      ..writeByte(6)
      ..write(obj.accuracyM);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripSampleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
