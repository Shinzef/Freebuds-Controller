import 'package:flutter/services.dart';

class FreeBudsService {
  static const MethodChannel _channel = MethodChannel('freebuds/bluetooth');

  static Future<bool> connectDevice([String deviceName = "HUAWEI FreeBuds 6i"]) async {
    try {
      final result = await _channel.invokeMethod('connectDevice', {'deviceName': deviceName});
      return result == true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  static Future<bool> disconnectDevice() async {
    try {
      final result = await _channel.invokeMethod('disconnectDevice');
      return result == true;
    } catch (e) {
      print('Disconnect error: $e');
      return false;
    }
  }

  static Future<String?> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod('getDeviceInfo');
      return result as String?;
    } catch (e) {
      print('Get device info error: $e');
      return null;
    }
  }

  static Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod('isConnected');
      return result == true;
    } catch (e) {
      print('Is connected error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getBatteryInfo() async {
    try {
      final result = await _channel.invokeMethod('getBatteryInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Get battery info error: $e');
      return null;
    }
  }
  static Future<bool> setAncMode(int mode) async {
    try {
      final result = await _channel.invokeMethod('setAncMode', {'mode': mode});
      return result == true;
    } catch (e) {
      print('Set ANC mode error: $e');
      return false;
    }
  }

  static Future<bool> setAncLevel(int level) async {
    return await _channel.invokeMethod('setAncLevel', {'level': level}) ?? false;
  }

   static Future<bool> getWearDetection() async {
    return await _channel.invokeMethod('getWearDetection') ?? false;
  }

  static Future<bool> setWearDetection(bool enable) async {
    return await _channel.invokeMethod('setWearDetection', {'enable': enable}) ?? false;
  }

  static Future<bool> getLowLatency() async {
    return await _channel.invokeMethod('getLowLatency') ?? false;
  }

  static Future<bool> setLowLatency(bool enable) async {
    return await _channel.invokeMethod('setLowLatency', {'enable': enable}) ?? false;
  }

  static Future<int> getSoundQuality() async {
    return await _channel.invokeMethod('getSoundQuality') ?? 0;
  }

  static Future<bool> setSoundQuality(int preference) async {
    return await _channel.invokeMethod('setSoundQuality', {'preference': preference}) ?? false;
  }

  static Future<Map<String, dynamic>?> getAncStatus() async {
    final result = await _channel.invokeMethod('getAncStatus');
    // The result from JNI is Map<String, Int>, we cast it for Dart
    if (result == null) return null;
    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>?> getGestureSettings() async {
    try {
      final result = await _channel.invokeMethod('getGestureSettings');
      if (result == null) return null;
      // The result from Kotlin is a Map<String, Int>, we cast it for Dart
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Get gesture settings error: $e');
      return null;
    }
  }

  static Future<bool> setDoubleTapAction(int side, int action) async {
    return await _channel.invokeMethod('setDoubleTapAction', {'side': side, 'action': action}) ?? false;
  }

  static Future<bool> setTripleTapAction(int side, int action) async {
    return await _channel.invokeMethod('setTripleTapAction', {'side': side, 'action': action}) ?? false;
  }

  static Future<bool> setLongTapAction(int side, int action) async {
    return await _channel.invokeMethod('setLongTapAction', {'side': side, 'action': action}) ?? false;
  }

  static Future<bool> setSwipeAction(int action) async {
    return await _channel.invokeMethod('setSwipeAction', {'action': action}) ?? false;
  }

  static Future<Map<String, dynamic>?> getEqualizerInfo() async {
    try {
      final result = await _channel.invokeMethod('getEqualizerInfo');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Get Equalizer info error: $e');
      return null;
    }
  }

  static Future<bool> setEqualizerPreset(int presetId) async {
    return await _channel.invokeMethod('setEqualizerPreset', {'presetId': presetId}) ?? false;
  }

  static Future<bool> createOrUpdateCustomEq(int id, String name, List<int> values) async {
    return await _channel.invokeMethod('createOrUpdateCustomEq', {
      'id': id,
      'name': name,
      'values': values,
    }) ?? false;
  }

  static Future<bool> deleteCustomEq(int presetId) async {
    return await _channel.invokeMethod('deleteCustomEq', {'presetId': presetId}) ?? false;
  }
}
