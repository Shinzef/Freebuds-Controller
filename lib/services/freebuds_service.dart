import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'dart:isolate';
import 'dart:convert';

// FFI Bridge for Windows DLL
class FFIBridge {
  static final _dll = DynamicLibrary.open('OpenFreebudsCore.dll');

  // Function signatures
  static final initialize = _dll
      .lookupFunction<Void Function(), void Function()>('Initialize');
  static final connect = _dll
      .lookupFunction<
        Bool Function(Pointer<Utf8>),
        bool Function(Pointer<Utf8>)
      >('Connect');
  static final disconnect = _dll
      .lookupFunction<Void Function(), void Function()>('Disconnect');
  static final isConnected = _dll
      .lookupFunction<Bool Function(), bool Function()>('IsConnected');
  static final getDeviceInfo = _dll
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'GetDeviceInfo',
      );
  static final getBatteryInfo = _dll
      .lookupFunction<
        Bool Function(Pointer<Int32>, Pointer<Int32>, Pointer<Int32>),
        bool Function(Pointer<Int32>, Pointer<Int32>, Pointer<Int32>)
      >('GetBatteryInfo');
  static final setAncMode = _dll
      .lookupFunction<Bool Function(Int32), bool Function(int)>('SetAncMode');
  static final setAncLevel = _dll
      .lookupFunction<Bool Function(Int32), bool Function(int)>('SetAncLevel');
  static final getAncStatus = _dll
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'GetAncStatus',
      );
  static final getWearDetection = _dll
      .lookupFunction<Bool Function(), bool Function()>('GetWearDetection');
  static final setWearDetection = _dll
      .lookupFunction<Bool Function(Bool), bool Function(bool)>(
        'SetWearDetection',
      );
  static final getLowLatency = _dll
      .lookupFunction<Bool Function(), bool Function()>('GetLowLatency');
  static final setLowLatency = _dll
      .lookupFunction<Bool Function(Bool), bool Function(bool)>(
        'SetLowLatency',
      );
  static final getSoundQuality = _dll
      .lookupFunction<Int32 Function(), int Function()>('GetSoundQuality');
  static final setSoundQuality = _dll
      .lookupFunction<Bool Function(Int32), bool Function(int)>(
        'SetSoundQuality',
      );
  static final getGestureSettings = _dll
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'GetGestureSettings',
      );
  static final setDoubleTapAction = _dll
      .lookupFunction<Bool Function(Int32, Int32), bool Function(int, int)>(
        'SetDoubleTapAction',
      );
  static final setTripleTapAction = _dll
      .lookupFunction<Bool Function(Int32, Int32), bool Function(int, int)>(
        'SetTripleTapAction',
      );
  static final setLongTapAction = _dll
      .lookupFunction<Bool Function(Int32, Int32), bool Function(int, int)>(
        'SetLongTapAction',
      );
  static final setSwipeAction = _dll
      .lookupFunction<Bool Function(Int32), bool Function(int)>(
        'SetSwipeAction',
      );
  static final getEqualizerInfo = _dll
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'GetEqualizerInfo',
      );
  static final setEqualizerPreset = _dll
      .lookupFunction<Bool Function(Int32), bool Function(int)>(
        'SetEqualizerPreset',
      );
  static final createOrUpdateCustomEq = _dll
      .lookupFunction<
        Bool Function(Int32, Pointer<Utf8>, Pointer<Int32>, Int32),
        bool Function(int, Pointer<Utf8>, Pointer<Int32>, int)
      >('CreateOrUpdateCustomEq');
  static final deleteCustomEq = _dll
      .lookupFunction<
        Bool Function(Pointer<Utf8>),
        bool Function(Pointer<Utf8>)
      >('DeleteCustomEq');
  static final getDualConnectDevices = _dll
      .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'GetDualConnectDevices',
      );
  static final dualConnectAction = _dll
      .lookupFunction<
        Bool Function(Pointer<Utf8>, Int32),
        bool Function(Pointer<Utf8>, int)
      >('DualConnectAction');
  static final createFakePreset = _dll
      .lookupFunction<Bool Function(Int32, Int32), bool Function(int, int)>(
        'CreateFakePreset',
      );
}

// Top-level function for the isolate
Future<bool> _connectDeviceIsolate(String deviceName) async {
  // This function runs in a separate isolate.
  // We can't access platform channels or FFI directly from here
  // in the same way, but for this specific case, we are assuming
  // the platform-specific implementation is thread-safe or can be
  // called from a different context.

  // NOTE: Direct FFI from a non-main isolate can be tricky.
  // A more robust solution might involve a true Isolate with ports if
  // the DLL is not thread-safe. For now, we'll proceed with `compute`.
  try {
    if (Platform.isAndroid) {
      // Platform channels are safe to call from any isolate.
      final result =
          await FreeBudsService._channel.invokeMethod('connectDevice', {
        'deviceName': deviceName,
      });
      return result == true;
    } else if (Platform.isWindows) {
      // FFI calls *might* not be safe from other isolates depending on the DLL.
      // We are assuming it's safe for this implementation.
      FFIBridge.initialize(); // Ensure it's initialized in this isolate's context
      final namePtr = deviceName.toNativeUtf8();
      final result = FFIBridge.connect(namePtr);
      calloc.free(namePtr);
      return result;
    }
    return false;
  } catch (e) {
    // It's good practice to handle potential errors within the isolate
    print('Connection error in isolate: $e');
    return false;
  }
}

class FreeBudsService {
  static const MethodChannel _channel = MethodChannel('freebuds/bluetooth');
  static bool _isWindowsInitialized = false;

  static void _ensureWindowsInitialized() {
    if (Platform.isWindows && !_isWindowsInitialized) {
      FFIBridge.initialize();
      _isWindowsInitialized = true;
    }
  }

  static Future<bool> connectDevice([
    String deviceName = "HUAWEI FreeBuds 6i",
  ]) async {
    // Use Flutter's `compute` function to run the connection logic in a background isolate.
    return await compute(_connectDeviceIsolate, deviceName);
  }

  static Future<bool> disconnectDevice() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('disconnectDevice');
        return result == true;
      } else if (Platform.isWindows) {
        FFIBridge.disconnect();
        return true;
      }
      return false;
    } catch (e) {
      print('Disconnect error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final String? result = await _channel.invokeMethod('getDeviceInfo');
        if (result == null) return null;
        final map = <String, dynamic>{};
        for (var line in result.split('\n')) {
          final parts = line.split(': ');
          if (parts.length == 2) {
            map[parts[0].toLowerCase().replaceAll(' ', '_')] = parts[1];
          }
        }
        return map;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final resultPtr = FFIBridge.getDeviceInfo();
        if (resultPtr.address == 0) return null;
        final jsonString = resultPtr.toDartString();
        print(resultPtr.toDartString());
        return jsonDecode(jsonString);
      }
      return null;
    } catch (e) {
      print('Get device info error: $e');
      return null;
    }
  }

  static Future<bool> isConnected() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('isConnected');
        return result == true;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.isConnected();
      }
      return false;
    } catch (e) {
      print('Is connected error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getBatteryInfo() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getBatteryInfo');
        return Map<String, dynamic>.from(result);
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final leftPtr = calloc<Int32>();
        final rightPtr = calloc<Int32>();
        final casePtr = calloc<Int32>();

        final success = FFIBridge.getBatteryInfo(leftPtr, rightPtr, casePtr);
        if (success) {
          final result = {
            'left': leftPtr.value,
            'right': rightPtr.value,
            'case': casePtr.value,
          };
          calloc.free(leftPtr);
          calloc.free(rightPtr);
          calloc.free(casePtr);
          return result;
        }

        calloc.free(leftPtr);
        calloc.free(rightPtr);
        calloc.free(casePtr);
        return null;
      }
      return null;
    } catch (e) {
      print('Get battery info error: $e');
      return null;
    }
  }

  static Future<bool> setAncMode(int mode) async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('setAncMode', {
          'mode': mode,
        });
        return result == true;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setAncMode(mode);
      }
      return false;
    } catch (e) {
      print('Set ANC mode error: $e');
      return false;
    }
  }

  static Future<bool> setAncLevel(int level) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setAncLevel', {'level': level}) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setAncLevel(level);
      }
      return false;
    } catch (e) {
      print('Set ANC level error: $e');
      return false;
    }
  }

  static Future<bool> getWearDetection() async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('getWearDetection') ?? false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.getWearDetection();
      }
      return false;
    } catch (e) {
      print('Get wear detection error: $e');
      return false;
    }
  }

  static Future<bool> setWearDetection(bool enable) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setWearDetection', {
              'enable': enable,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setWearDetection(enable);
      }
      return false;
    } catch (e) {
      print('Set wear detection error: $e');
      return false;
    }
  }

  static Future<bool> getLowLatency() async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('getLowLatency') ?? false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.getLowLatency();
      }
      return false;
    } catch (e) {
      print('Get low latency error: $e');
      return false;
    }
  }

  static Future<bool> setLowLatency(bool enable) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setLowLatency', {
              'enable': enable,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setLowLatency(enable);
      }
      return false;
    } catch (e) {
      print('Set low latency error: $e');
      return false;
    }
  }

  static Future<int> getSoundQuality() async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('getSoundQuality') ?? 0;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.getSoundQuality();
      }
      return 0;
    } catch (e) {
      print('Get sound quality error: $e');
      return 0;
    }
  }

  static Future<bool> setSoundQuality(int preference) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setSoundQuality', {
              'preference': preference,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setSoundQuality(preference);
      }
      return false;
    } catch (e) {
      print('Set sound quality error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getAncStatus() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getAncStatus');
        if (result == null) return null;
        return Map<String, dynamic>.from(result);
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final resultPtr = FFIBridge.getAncStatus();
        if (resultPtr.address == 0) return null;
        final jsonString = resultPtr.toDartString();
        // //calloc.free(resultPtr);
        return jsonDecode(jsonString);
      }
      return null;
    } catch (e) {
      print('Get ANC status error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getGestureSettings() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getGestureSettings');
        if (result == null) return null;
        return Map<String, dynamic>.from(result);
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final resultPtr = FFIBridge.getGestureSettings();
        if (resultPtr.address == 0) return null;
        return await compute(_getGestureSettingsWindows, null);
      }
      return null;
    } catch (e) {
      print('Get gesture settings error: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _getGestureSettingsWindows(_) {
    try {
      final resultPtr = FFIBridge.getGestureSettings();
      if (resultPtr.address == 0) return null;
      final jsonString = resultPtr.toDartString();
      //calloc.free(resultPtr);
      return jsonDecode(jsonString);
    } catch (e) {
      print('Windows FFI error: $e');
      return null;
    }
  }

  static Future<bool> setDoubleTapAction(int side, int action) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setDoubleTapAction', {
              'side': side,
              'action': action,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setDoubleTapAction(side, action);
      }
      return false;
    } catch (e) {
      print('Set double tap action error: $e');
      return false;
    }
  }

  static Future<bool> setTripleTapAction(int side, int action) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setTripleTapAction', {
              'side': side,
              'action': action,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setTripleTapAction(side, action);
      }
      return false;
    } catch (e) {
      print('Set triple tap action error: $e');
      return false;
    }
  }

  static Future<bool> setLongTapAction(int side, int action) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setLongTapAction', {
              'side': side,
              'action': action,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setLongTapAction(side, action);
      }
      return false;
    } catch (e) {
      print('Set long tap action error: $e');
      return false;
    }
  }

  static Future<bool> setSwipeAction(int action) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setSwipeAction', {
              'action': action,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setSwipeAction(action);
      }
      return false;
    } catch (e) {
      print('Set swipe action error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getEqualizerInfo() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getEqualizerInfo');
        if (result == null) return null;
        return Map<String, dynamic>.from(result);
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final resultPtr = FFIBridge.getEqualizerInfo();
        if (resultPtr.address == 0) return null;
        final jsonString = resultPtr.toDartString();
        //calloc.free(resultPtr);
        return jsonDecode(jsonString);
      }
      return null;
    } catch (e) {
      print('Get Equalizer info error: $e');
      return null;
    }
  }

  static Future<bool> setEqualizerPreset(int presetId) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('setEqualizerPreset', {
              'presetId': presetId,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.setEqualizerPreset(presetId);
      }
      return false;
    } catch (e) {
      print('Set equalizer preset error: $e');
      return false;
    }
  }

  static Future<bool> createOrUpdateCustomEq(
    int id,
    String name,
    List<int> values,
  ) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('createOrUpdateCustomEq', {
              'id': id,
              'name': name,
              'values': values,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final namePtr = name.toNativeUtf8();
        final valuesPtr = calloc<Int32>(values.length);
        for (int i = 0; i < values.length; i++) {
          valuesPtr[i] = values[i];
        }
        final result = FFIBridge.createOrUpdateCustomEq(
          id,
          namePtr,
          valuesPtr,
          values.length,
        );
        calloc.free(namePtr);
        calloc.free(valuesPtr);
        return result;
      }
      return false;
    } catch (e) {
      print('Create or update custom EQ error: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomEq(Map<dynamic, dynamic> preset) async {
    try {
      if (Platform.isAndroid) {
        final valuesToSend = List<int>.from(preset['values']);
        final presetToSend = {
          'id': preset['id'],
          'name': preset['name'],
          'values': valuesToSend,
        };
        return await _channel.invokeMethod('deleteCustomEq', {
              'preset': presetToSend,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final presetJson = jsonEncode(preset);
        final presetPtr = presetJson.toNativeUtf8();
        final result = FFIBridge.deleteCustomEq(presetPtr);
        calloc.free(presetPtr);
        return result;
      }
      return false;
    } catch (e) {
      print('Delete custom EQ error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> getDualConnectDevices() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<List<dynamic>>(
          'getDualConnectDevices',
        );
        if (result == null) return null;
        return result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final resultPtr = FFIBridge.getDualConnectDevices();
        if (resultPtr.address == 0) return null;
        final jsonString = resultPtr.toDartString();
        //calloc.free(resultPtr);
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return null;
    } catch (e) {
      print('Get Dual Connect devices error: $e');
      return null;
    }
  }

  static Future<bool> dualConnectAction(
    String macAddress,
    int actionCode,
  ) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('dualConnectAction', {
              'mac': macAddress,
              'code': actionCode,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        final macPtr = macAddress.toNativeUtf8();
        final result = FFIBridge.dualConnectAction(macPtr, actionCode);
        calloc.free(macPtr);
        return result;
      }
      return false;
    } catch (e) {
      print('Dual connect action error: $e');
      return false;
    }
  }

  static Future<bool> createFakePreset(int fakePresetType, int newId) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('createFakePreset', {
              'presetType': fakePresetType,
              'newId': newId,
            }) ??
            false;
      } else if (Platform.isWindows) {
        _ensureWindowsInitialized();
        return FFIBridge.createFakePreset(fakePresetType, newId);
      }
      return false;
    } catch (e) {
      print('Create fake preset error: $e');
      return false;
    }
  }
}
