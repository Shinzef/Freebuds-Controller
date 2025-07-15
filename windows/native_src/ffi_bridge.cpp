// in windows/native_src/ffi_bridge.cpp

#if defined(_WIN32)
// If we are building a Windows DLL, we want to export our functions.
#define FFI_EXPORT __declspec(dllexport)
#else
// For other platforms, we don't need any special keywords.
#define FFI_EXPORT
#endif

#include "core/device.h"
#include "core/types.h"
#include "platform/windows/bluetooth_spp_client.h"
#include "platform/windows/device_discovery.h"
#include <iomanip>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <windows.h>
#include <iostream>

// Global device object for our single-device controller app.
std::unique_ptr<Device> g_device;

// A reusable buffer for returning JSON strings to Dart. Simple and effective for this app.
static char json_buffer[4096];

// --- Helper Functions for converting between Dart/C++ types ---
static AncMode intToAncMode(int mode) {
	switch (mode) {
		case 0: return AncMode::NORMAL;
		case 1: return AncMode::CANCELLATION;
		case 2: return AncMode::AWARENESS;
		default: return AncMode::UNKNOWN;
	}
}
static AncLevel intToAncLevel(int level) {
	switch (level) {
		case 0: return AncLevel::COMFORTABLE;
		case 1: return AncLevel::NORMAL_CANCELLATION;
		case 2: return AncLevel::ULTRA;
		case 3: return AncLevel::DYNAMIC;
		case 4: return AncLevel::VOICE_BOOST;
		case 6: return AncLevel::NORMAL_AWARENESS;
		default: return AncLevel::UNKNOWN;
	}
}
static GestureAction intToGestureAction(int a) {
	switch (a) {
		case 1: return GestureAction::PLAY_PAUSE;
		case 2: return GestureAction::NEXT_TRACK;
		case 7: return GestureAction::PREV_TRACK;
		case 0: return GestureAction::VOICE_ASSISTANT;
		case -1: return GestureAction::OFF;
		case 8: return GestureAction::CHANGE_VOLUME;
		case 10: return GestureAction::SWITCH_ANC;
		default: return GestureAction::UNKNOWN;
	}
}
static int gestureActionToInt(GestureAction a) {
	switch (a) {
		case GestureAction::PLAY_PAUSE: return 1;
		case GestureAction::NEXT_TRACK: return 2;
		case GestureAction::PREV_TRACK: return 7;
		case GestureAction::VOICE_ASSISTANT: return 0;
		case GestureAction::OFF: return -1;
		case GestureAction::CHANGE_VOLUME: return 8;
		case GestureAction::SWITCH_ANC: return 10;
		default: return -99;
	}
}

static EarSide intToEarSide(int side) {
	return (side == 0) ? EarSide::LEFT : EarSide::RIGHT;
}
static FakePreset intToFakePreset(int type) {
	return (type == 0) ? FakePreset::SYMPHONY : FakePreset::HI_FI_LIVE;
}

extern "C" {// Use C-style linkage to prevent C++ name mangling
FFI_EXPORT void Initialize() {
	if (g_device) return;
	auto bt_client = std::make_unique<BluetoothSPPClient>();
	g_device = std::make_unique<Device>(std::move(bt_client));
}
FFI_EXPORT bool Connect(const char *name_utf8) {
	if (!g_device) Initialize();

	std::cout << "BRIDGE: Attempting to connect to device name (UTF-8): " << name_utf8 << std::endl;

	// If the input is null or empty, fail early.
	if (name_utf8 == nullptr || name_utf8[0] == '\0') {
		std::cerr << "BRIDGE: ERROR - Device name is empty." << std::endl;
		return false;
	}

	int size_excluding_null = MultiByteToWideChar(CP_UTF8, 0, name_utf8, -1, NULL, 0);
	if (size_excluding_null <= 0) {
		std::cerr << "BRIDGE: ERROR - Could not calculate wide string size." << std::endl;
		return false;
	}

	std::wstring name_wide(size_excluding_null - 1, 0);

	MultiByteToWideChar(CP_UTF8, 0, name_utf8, -1, &name_wide[0], size_excluding_null);

//  int size = MultiByteToWideChar(CP_UTF8, 0, name_utf8, -1, NULL, 0);
//  std::wstring name_wide(size, 0);
//  MultiByteToWideChar(CP_UTF8, 0, name_utf8, -1, &name_wide[0], size);

	std::wcout << L"BRIDGE: Converted to wide string: " << name_wide << std::endl;

	auto addr = find_first_device_by_name(name_wide);

	if (addr) {
		std::cout << "BRIDGE: Device found! MAC Address: " << addr.value() << std::endl;
	} else {
		std::cerr
			<< "BRIDGE: ERROR - Device discovery failed. Could not find a paired device with that name."
			<< std::endl;
		return false; // Fail early if not found
	}

	try {
		bool result = g_device->connect(addr.value(), 1);
		if (!result) {
			std::cerr << "BRIDGE: g_device->connect() returned false." << std::endl;
		}
		return result;
	} catch (const std::exception &e) {
		std::cerr << "BRIDGE: FATAL - Caught a C++ exception during connect: " << e.what()
				  << std::endl;
		return false;
	} catch (...) {
		std::cerr << "BRIDGE: FATAL - Caught an unknown C++ exception during connect." << std::endl;
		return false;
	}

	return addr ? g_device->connect(addr.value(), 1) : false;
}
FFI_EXPORT void Disconnect() {
	if (g_device) g_device->disconnect();
}
FFI_EXPORT bool IsConnected() { return g_device && g_device->is_connected(); }

FFI_EXPORT const char *GetDeviceInfo() {
	std::cout << "BRIDGE: Executing GetDeviceInfo..." << std::endl;
	if (!IsConnected()) {
		snprintf(json_buffer,
				 sizeof(json_buffer),
				 "{\"error\":\"Not connected\"}");
		return json_buffer;
	}
	try {
		auto i = g_device->get_device_info();
		snprintf(json_buffer, sizeof(json_buffer),
				 "{\"model\":\"%s\", \"firmware_version\":\"%s\", \"serial_number\":\"%s\"}",
				 i->model.c_str(), i->firmware_version.c_str(), i->serial_number.c_str());
	} catch (const std::exception &e) {
		snprintf(json_buffer,
				 sizeof(json_buffer),
				 "{\"error\":\"Exception in GetDeviceInfo: %s\"}",
				 e.what());
	}
	return json_buffer;
}

FFI_EXPORT bool GetBatteryInfo(int *l, int *r, int *c) {
	std::cout << "BRIDGE: Executing GetBatteryInfo..." << std::endl;
	if (!IsConnected()) return false;
	try {
		if (auto i = g_device->get_battery_info()) {
			*l = i->left;
			*r = i->right;
			*c = i->case_level;
			return true;
		}
	} catch (const std::exception &e) {
		std::cerr << "BRIDGE: FATAL - Caught exception in GetBatteryInfo: " << e.what()
				  << std::endl;
	}
	return false;
}

FFI_EXPORT const char *GetAncStatus() {
	std::cout << "BRIDGE: Executing GetAncStatus..." << std::endl;
	if (!IsConnected()) {
		snprintf(json_buffer, sizeof(json_buffer), "{}");
		return json_buffer;
	}
	try {
		auto s = g_device->get_anc_status();
		snprintf(json_buffer, sizeof(json_buffer), "{\"mode\":%d,\"level\":%d}",
				 s ? (int)s->mode : 0, s ? (int)s->level : 0);
	} catch (const std::exception &e) {
		snprintf(json_buffer,
				 sizeof(json_buffer),
				 "{\"error\":\"Exception in GetAncStatus: %s\"}",
				 e.what());
	}
	return json_buffer;
}

FFI_EXPORT bool GetWearDetection() {
	return IsConnected() && g_device->get_wear_detection_status().value_or(false);
}
FFI_EXPORT bool GetLowLatency() {
	return IsConnected() && g_device->get_low_latency_status().value_or(false);
}
FFI_EXPORT int GetSoundQuality() {
	return IsConnected() ? (int)g_device->get_sound_quality_preference()
		.value_or(SoundQualityPreference::PRIORITIZE_CONNECTION) : 0;
}

FFI_EXPORT bool SetAncMode(int m) {
	return IsConnected() && g_device->set_anc_mode(intToAncMode(m));
}
FFI_EXPORT bool SetAncLevel(int l) {
	return IsConnected() && g_device->set_anc_level(intToAncLevel(l));
}
FFI_EXPORT bool SetWearDetection(bool e) {
	return IsConnected() && g_device->set_wear_detection(e);
}
FFI_EXPORT bool SetLowLatency(bool e) { return IsConnected() && g_device->set_low_latency(e); }
FFI_EXPORT bool SetSoundQuality(int p) {
	return IsConnected() && g_device->set_sound_quality_preference((SoundQualityPreference)p);
}

// --- Gestures ---
FFI_EXPORT const char *GetGestureSettings() {
	std::cout << "BRIDGE: Executing GetGestureSettings..." << std::endl;
	if (!IsConnected()) {
		snprintf(json_buffer, sizeof(json_buffer), "{}");
		return json_buffer;
	}
	try {
		auto s = g_device->get_all_gesture_settings();
		if (s) {
			snprintf(json_buffer,
					 sizeof(json_buffer),
					 "{\"double_tap_left\":%d,\"double_tap_right\":%d,\"triple_tap_left\":%d,\"triple_tap_right\":%d,\"long_tap_left\":%d,\"long_tap_right\":%d,\"swipe_action\":%d}",
					 gestureActionToInt(s->double_tap_left),
					 gestureActionToInt(s->double_tap_right),
					 gestureActionToInt(s->triple_tap_left),
					 gestureActionToInt(s->triple_tap_right),
					 gestureActionToInt(s->long_tap_left),
					 gestureActionToInt(s->long_tap_right),
					 gestureActionToInt(s->swipe_action));
		} else {
			snprintf(json_buffer, sizeof(json_buffer), "{}");
		}
	} catch (const std::exception &e) {
		snprintf(json_buffer,
				 sizeof(json_buffer),
				 "{\"error\":\"Exception in GetGestureSettings: %s\"}",
				 e.what());
	}
	return json_buffer;
}

FFI_EXPORT bool SetDoubleTapAction(int s, int a) {
	return IsConnected() && g_device->set_double_tap_action(intToEarSide(s), intToGestureAction(a));
}
FFI_EXPORT bool SetTripleTapAction(int s, int a) {
	return IsConnected() && g_device->set_triple_tap_action(intToEarSide(s), intToGestureAction(a));
}
FFI_EXPORT bool SetLongTapAction(int s, int a) {
	return IsConnected() && g_device->set_long_tap_action(intToEarSide(s), intToGestureAction(a));
}
FFI_EXPORT bool SetSwipeAction(int a) {
	return IsConnected() && g_device->set_swipe_action(intToGestureAction(a));
}

// --- Equalizer ---
FFI_EXPORT const char *GetEqualizerInfo() {
	std::cout << "BRIDGE: Executing GetEqualizerInfo..." << std::endl;
	if (!IsConnected()) {
		snprintf(json_buffer, sizeof(json_buffer), "{}");
		return json_buffer;
	}
	try {
		auto info = g_device->get_equalizer_info();
		if (info) {
			std::ostringstream ss;
			ss << "{\"current_preset_id\":" << (int)info->current_preset_id
			   << ",\"built_in_preset_ids\":[";
			for (size_t i = 0; i < info->built_in_preset_ids.size(); ++i)
				ss << (int)info->built_in_preset_ids[i]
				   << (i == info->built_in_preset_ids.size() - 1 ? "" : ",");
			ss << "],\"custom_presets\":[";
			for (size_t i = 0; i < info->custom_presets.size(); ++i) {
				ss << "{\"id\":" << (int)info->custom_presets[i].id << ",\"name\":\""
				   << info->custom_presets[i].name << "\",\"values\":[";
				for (size_t j = 0; j < info->custom_presets[i].values.size(); ++j)
					ss << (int)info->custom_presets[i].values[j]
					   << (j == info->custom_presets[i].values.size() - 1 ? "" : ",");
				ss << "]}";
				if (i != info->custom_presets.size() - 1) ss << ",";
			}
			ss << "]}";
			snprintf(json_buffer, sizeof(json_buffer), "%s", ss.str().c_str());
		} else {
			snprintf(json_buffer, sizeof(json_buffer), "{}");
		}
	} catch (const std::exception &e) {
		snprintf(json_buffer,
				 sizeof(json_buffer),
				 "{\"error\":\"Exception in GetEqualizerInfo: %s\"}",
				 e.what());
	}
	return json_buffer;
}
FFI_EXPORT bool SetEqualizerPreset(int id) {
	if (!IsConnected() || id < 0 || id > 255) return false;
	return g_device->set_equalizer_preset(static_cast<uint8_t>(id));
}

FFI_EXPORT bool CreateOrUpdateCustomEq(int id, const char *name_utf8, const int *values, int len) {
	if (!IsConnected() || len != 10) return false;
	CustomEqPreset p;
	p.id = static_cast<uint8_t>(id);// Fix for line 185
	p.name = std::string(name_utf8);
	for (int i = 0; i < len; ++i) {
		p.values.push_back(static_cast<int8_t>(values[i]));// Fix for line 180
	}
	return g_device->create_or_update_custom_equalizer(p);
}

FFI_EXPORT bool DeleteCustomEq(int id, const char *name_utf8, const int *values, int len) {
	if (!IsConnected() || len != 10) return false;
	CustomEqPreset p;
	p.id = static_cast<uint8_t>(id);
	p.name = std::string(name_utf8);
	for (int i = 0; i < len; ++i) {
		p.values.push_back(static_cast<int8_t>(values[i]));
	}
	return g_device->delete_custom_equalizer(p);
}

FFI_EXPORT bool CreateFakePreset(int type, int id) {
	return IsConnected()
		&& g_device->create_fake_preset(intToFakePreset(type), static_cast<uint8_t>(id));
}

// --- Dual Connect ---
FFI_EXPORT const char *GetDualConnectDevices() {
	if (!IsConnected()) {
		snprintf(json_buffer, sizeof(json_buffer), "[]");
		return json_buffer;
	}
	auto devices = g_device->get_dual_connect_devices();
	std::ostringstream ss;
	ss << "[";
	for (size_t i = 0; i < devices.size(); ++i) {
		ss << "{\"mac_address\":\"" << devices[i].mac_address << "\",\"name\":\"" << devices[i].name
		   << "\",\"is_connected\":" << (devices[i].is_connected ? "true" : "false")
		   << ",\"is_playing\":" << (devices[i].is_playing ? "true" : "false") << "}";
		if (i != devices.size() - 1) ss << ",";
	}
	ss << "]";
	snprintf(json_buffer, sizeof(json_buffer), "%s", ss.str().c_str());
	return json_buffer;
}
FFI_EXPORT bool DualConnectAction(const char *mac_utf8, int code) {
	if (!IsConnected() || code < 0 || code > 255) return false;
	return g_device->dual_connect_action(std::string(mac_utf8), static_cast<uint8_t>(code));
}
}