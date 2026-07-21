// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bar_drop_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BarDropEventAdapter extends TypeAdapter<BarDropEvent> {
  @override
  final int typeId = 4;

  @override
  BarDropEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BarDropEvent(
      tripId: fields[0] as String,
      timestampMs: fields[1] as int,
      barLevelAfterDrop: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BarDropEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.timestampMs)
      ..writeByte(2)
      ..write(obj.barLevelAfterDrop);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarDropEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
