import 'dart:typed_data';

import 'package:flutter_reactive_ble/src/generated/bledata.pb.dart' as pb;
import 'package:flutter_reactive_ble/src/model/ble_status.dart';
import 'package:flutter_reactive_ble/src/model/characteristic_value.dart';
import 'package:flutter_reactive_ble/src/model/clear_gatt_cache_error.dart';
import 'package:flutter_reactive_ble/src/model/connection_priority.dart';
import 'package:flutter_reactive_ble/src/model/connection_state_update.dart';
import 'package:flutter_reactive_ble/src/model/discovered_device.dart';
import 'package:flutter_reactive_ble/src/model/generic_failure.dart';
import 'package:flutter_reactive_ble/src/model/qualified_characteristic.dart';
import 'package:flutter_reactive_ble/src/model/result.dart';
import 'package:flutter_reactive_ble/src/model/uuid.dart';
import 'package:flutter_reactive_ble/src/model/write_characteristic_info.dart';
import 'package:flutter_reactive_ble/src/select_from.dart';
import 'package:meta/meta.dart';

class ProtobufConverter {
  const ProtobufConverter();

  BleStatus bleStatusFrom(pb.BleStatusInfo message) =>
      selectFrom(BleStatus.values,
          index: message.status, fallback: (_) => BleStatus.unknown);

  ScanResult scanResultFrom(pb.DeviceScanInfo message) {
    final serviceData = Map.fromIterables(
      message.serviceData.map((entry) => Uuid(entry.serviceUuid.data)),
      message.serviceData.map((entry) => Uint8List.fromList(entry.data)),
    );

    return ScanResult(
      result: resultFrom(
          getValue: () => DiscoveredDevice(
              id: message.id, name: message.name, serviceData: serviceData),
          failure: genericFailureFrom(
              hasFailure: message.hasFailure(),
              getFailure: () => message.failure,
              codes: ScanFailure.values,
              fallback: (rawOrNull) => ScanFailure.unknown)),
    );
  }

  ConnectionStateUpdate connectionStateUpdateFrom(pb.DeviceInfo deviceInfo) =>
      ConnectionStateUpdate(
        deviceId: deviceInfo.id,
        connectionState: selectFrom(
          DeviceConnectionState.values,
          index: deviceInfo.connectionState,
          fallback: (raw) => throw _InvalidConnectionState(raw),
        ),
        failure: genericFailureFrom(
          hasFailure: deviceInfo.hasFailure(),
          getFailure: () => deviceInfo.failure,
          codes: ConnectionError.values,
          fallback: (rawOrNull) =>
              rawOrNull == null ? null : ConnectionError.unknown,
        ),
      );

  Result<void, GenericFailure<ClearGattCacheError>> clearGattCacheResultFrom(
          pb.ClearGattCacheInfo message) =>
      resultFrom(
        getValue: () {},
        failure: genericFailureFrom(
          hasFailure: message.hasFailure(),
          getFailure: () => message.failure,
          codes: ClearGattCacheError.values,
          fallback: (rawOrNull) => ClearGattCacheError.unknown,
        ),
      );

  CharacteristicValue characteristicValueFrom(
          pb.CharacteristicValueInfo message) =>
      CharacteristicValue(
        characteristic: qualifiedCharacteristicFrom(message.characteristic),
        result: resultFrom(
          getValue: () => message.value,
          failure: genericFailureFrom(
            hasFailure: message.hasFailure(),
            getFailure: () => message.failure,
            codes: CharacteristicValueUpdateError.values,
            fallback: (rawOrNull) => CharacteristicValueUpdateError.unknown,
          ),
        ),
      );

  WriteCharacteristicInfo writeCharacteristicInfoFrom(
          pb.WriteCharacteristicInfo message) =>
      WriteCharacteristicInfo(
        characteristic: qualifiedCharacteristicFrom(message.characteristic),
        result: resultFrom(
          getValue: () {},
          failure: genericFailureFrom(
            hasFailure: message.hasFailure(),
            getFailure: () => message.failure,
            codes: WriteCharacteristicFailure.values,
            fallback: (rawOrNull) => WriteCharacteristicFailure.unknown,
          ),
        ),
      );

  ConnectionPriorityInfo connectionPriorityInfoFrom(
          pb.ChangeConnectionPriorityInfo message) =>
      ConnectionPriorityInfo(
        result: resultFrom(
          getValue: () {},
          failure: genericFailureFrom(
            hasFailure: message.hasFailure(),
            getFailure: () => message.failure,
            codes: ConnectionPriorityFailure.values,
            fallback: (rawOrNull) => ConnectionPriorityFailure.unknown,
          ),
        ),
      );

  QualifiedCharacteristic qualifiedCharacteristicFrom(
          pb.CharacteristicAddress message) =>
      QualifiedCharacteristic(
        characteristicId: Uuid(message.characteristicUuid.data),
        serviceId: Uuid(message.serviceUuid.data),
        deviceId: message.deviceId,
      );

  @visibleForTesting
  GenericFailure<T> genericFailureFrom<T>({
    @required bool hasFailure,
    @required pb.GenericFailure Function() getFailure,
    @required List<T> codes,
    @required T Function(int rawOrNull) fallback,
  }) {
    if (hasFailure) {
      final error = getFailure();
      return GenericFailure(
        code: error.hasCode()
            ? selectFrom(codes, index: error.code, fallback: fallback)
            : fallback(null),
        message: error.message,
      );
    }
    return null;
  }

  @visibleForTesting
  Result<Value, Failure> resultFrom<Value, Failure>(
          {@required Value Function() getValue, @required Failure failure}) =>
      failure != null
          ? Result<Value, Failure>.failure(failure)
          : Result.success(getValue());
}

class _InvalidConnectionState extends Error {
  final int rawValue;

  _InvalidConnectionState(this.rawValue);

  @override
  String toString() => "Invalid $DeviceConnectionState value $rawValue";
}
