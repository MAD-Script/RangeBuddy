// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passenger.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PassengerAdapter extends TypeAdapter<Passenger> {
  @override
  final int typeId = 7;

  @override
  Passenger read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Passenger(
      name: fields[0] as String,
      weightKg: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Passenger obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weightKg);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassengerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
