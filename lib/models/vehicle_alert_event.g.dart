// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_alert_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehicleAlertEventAdapter extends TypeAdapter<VehicleAlertEvent> {
  @override
  final int typeId = 6;

  @override
  VehicleAlertEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VehicleAlertEvent(
      tripId: fields[0] as String,
      timestampMs: fields[1] as int,
      alertType: fields[2] as VehicleAlertType,
    );
  }

  @override
  void write(BinaryWriter writer, VehicleAlertEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.tripId)
      ..writeByte(1)
      ..write(obj.timestampMs)
      ..writeByte(2)
      ..write(obj.alertType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleAlertEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VehicleAlertTypeAdapter extends TypeAdapter<VehicleAlertType> {
  @override
  final int typeId = 5;

  @override
  VehicleAlertType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VehicleAlertType.lowBatteryAudibleWarning;
      case 1:
        return VehicleAlertType.refuelIndicatorOn;
      case 2:
        return VehicleAlertType.criticalBlinkingRed;
      default:
        return VehicleAlertType.lowBatteryAudibleWarning;
    }
  }

  @override
  void write(BinaryWriter writer, VehicleAlertType obj) {
    switch (obj) {
      case VehicleAlertType.lowBatteryAudibleWarning:
        writer.writeByte(0);
        break;
      case VehicleAlertType.refuelIndicatorOn:
        writer.writeByte(1);
        break;
      case VehicleAlertType.criticalBlinkingRed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleAlertTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
