// windows/native_src/ffi_bridge.cpp

#if defined(_WIN32)
#define FFI_EXPORT __declspec(dllexport)
#else
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

std::unique_ptr<Device> g_device;
static char json_buffer[4096];

// --- Helper Functions ---
// (These are unchanged)
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

extern "C" {

// --- Lifecycle (Unchanged) ---
FFI_EXPORT void Initialize() {
	if (g_device) return;
	auto bt_client = std::make_unique<BluetoothSPPClient>();
	g_device = std::make_unique<Device>(std::move(bt_client));
}

FFI_EXPORT bool Connect(const char* name_utf8) {
	if (!g_device) Initialize();

	std::cout << "[FFI_BRIDGE] Received request to connect to device name: " << (name_utf8 ? name_utf8 : "NULL") << std::endl;

	if (name_utf8 == nullptr || name_utf8[0] == '\0') {
		std::cerr << "[FFI_BRIDGE] ERROR: Device name is null or empty. Aborting." << std::endl;
		return false;
	}

	// --- START OF THE FIX ---

	// 1. Calculate the required buffer size. This size INCLUDES the null terminator.
	int size_including_null = MultiByteToWideChar(CP_UTF8, 0, name_utf8, -1, NULL, 0);
	if (size_including_null <= 0) {
		std::cerr << "[FFI_BRIDGE] ERROR: Could not calculate wide string size for conversion. Aborting." << std::endl;
		return false;
	}

	// 2. Create a std::wstring with the correct length, EXCLUDING the null terminator.
	std::wstring name_wide(size_including_null - 1, 0);

	// 3. Perform the conversion into the buffer provided by the wstring.
	//    The function will write the characters and the final null terminator.
	MultiByteToWideChar(CP_UTF8, 0, name_utf8, -1, &name_wide[0], size_including_null);

	// --- END OF THE FIX ---


	std::wcout << L"[FFI_BRIDGE] Converted name to wide string (should be clean now): '" << name_wide << L"'" << std::endl;

	std::cout << "[FFI_BRIDGE] Starting device discovery..." << std::endl;
	auto addr = find_first_device_by_name(name_wide);

	if (addr) {
		std::cout << "[FFI_BRIDGE] SUCCESS: Device found! MAC Address: " << addr.value() << std::endl;
	} else {
		std::cerr << "[FFI_BRIDGE] ERROR: Device discovery failed. Could not find a paired device with that exact name." << std::endl;
		std::cerr << "[FFI_BRIDGE] Please check Windows Bluetooth settings to ensure the device is paired and the name matches EXACTLY." << std::endl;
		return false;
	}

	std::cout << "[FFI_BRIDGE] Now passing MAC address to the C++ Device object to connect..." << std::endl;
	return g_device->connect(addr.value(), 1);
}

FFI_EXPORT void Disconnect() {
	if (g_device) g_device->disconnect();
}

FFI_EXPORT bool IsConnected() {
	return g_device && g_device->is_connected();
}


// --- Getters (Unchanged) ---
FFI_EXPORT const char* GetDeviceInfo() {
	if (!IsConnected()) { snprintf(json_buffer, sizeof(json_buffer), "{\"error\":\"Not connected\"}"); return json_buffer; }
	auto i = g_device->get_device_info();
	snprintf(json_buffer, sizeof(json_buffer), "{\"model\":\"%s\", \"firmware_version\":\"%s\", \"serial_number\":\"%s\"}", i->model.c_str(), i->firmware_version.c_str(), i->serial_number.c_str());
	return json_buffer;
}

FFI_EXPORT bool GetBatteryInfo(int* l, int* r, int* c) {
	if (!IsConnected()) return false;
	if (auto i = g_device->get_battery_info()) {
		*l = i->left; *r = i->right; *c = i->case_level;
		return true;
	}
	return false;
}

FFI_EXPORT const char* GetAncStatus() {
	if (!IsConnected()) { snprintf(json_buffer, sizeof(json_buffer), "{}"); return json_buffer; }
	auto s = g_device->get_anc_status();
	snprintf(json_buffer, sizeof(json_buffer), "{\"mode\":%d,\"level\":%d}", s ? (int)s->mode : 0, s ? (int)s->level : 0);
	return json_buffer;
}

FFI_EXPORT bool GetWearDetection() { return IsConnected() && g_device->get_wear_detection_status().value_or(false); }
FFI_EXPORT bool GetLowLatency() { return IsConnected() && g_device->get_low_latency_status().value_or(false); }
FFI_EXPORT int GetSoundQuality() { return IsConnected() ? (int)g_device->get_sound_quality_preference().value_or(SoundQualityPreference::PRIORITIZE_CONNECTION) : 0; }

// --- SETTERS (MODIFIED TO RETURN VOID) ---
FFI_EXPORT void SetAncMode(int m) {
	if (IsConnected()) g_device->set_anc_mode(intToAncMode(m));
}
FFI_EXPORT void SetAncLevel(int l) {
	if (IsConnected()) g_device->set_anc_level(intToAncLevel(l));
}
FFI_EXPORT void SetWearDetection(bool e) {
	if (IsConnected()) g_device->set_wear_detection(e);
}
FFI_EXPORT void SetLowLatency(bool e) {
	if (IsConnected()) g_device->set_low_latency(e);
}
FFI_EXPORT void SetSoundQuality(int p) {
	if (IsConnected()) g_device->set_sound_quality_preference((SoundQualityPreference)p);
}

// --- Gestures ---
FFI_EXPORT const char* GetGestureSettings() {
	if (!IsConnected()) { snprintf(json_buffer, sizeof(json_buffer), "{}"); return json_buffer; }
	auto s = g_device->get_all_gesture_settings();
	if (s) {
		snprintf(json_buffer, sizeof(json_buffer), "{\"double_tap_left\":%d,\"double_tap_right\":%d,\"triple_tap_left\":%d,\"triple_tap_right\":%d,\"long_tap_left\":%d,\"long_tap_right\":%d,\"swipe_action\":%d}",
				 gestureActionToInt(s->double_tap_left), gestureActionToInt(s->double_tap_right),
				 gestureActionToInt(s->triple_tap_left), gestureActionToInt(s->triple_tap_right),
				 gestureActionToInt(s->long_tap_left), gestureActionToInt(s->long_tap_right),
				 gestureActionToInt(s->swipe_action));
	} else {
		snprintf(json_buffer, sizeof(json_buffer), "{}");
	}
	return json_buffer;
}

FFI_EXPORT void SetDoubleTapAction(int s, int a) {
	if (IsConnected()) g_device->set_double_tap_action(intToEarSide(s), intToGestureAction(a));
}
FFI_EXPORT void SetTripleTapAction(int s, int a) {
	if (IsConnected()) g_device->set_triple_tap_action(intToEarSide(s), intToGestureAction(a));
}
FFI_EXPORT void SetLongTapAction(int s, int a) {
	if (IsConnected()) g_device->set_long_tap_action(intToEarSide(s), intToGestureAction(a));
}
FFI_EXPORT void SetSwipeAction(int a) {
	if (IsConnected()) g_device->set_swipe_action(intToGestureAction(a));
}

// --- Equalizer ---
FFI_EXPORT const char* GetEqualizerInfo() {
	if (!IsConnected()) { snprintf(json_buffer, sizeof(json_buffer), "{}"); return json_buffer; }
	auto info = g_device->get_equalizer_info();
	if (info) {
		std::ostringstream ss;
		ss << "{\"current_preset_id\":" << (int)info->current_preset_id << ",\"built_in_preset_ids\":[";
		for (size_t i = 0; i < info->built_in_preset_ids.size(); ++i) ss << (int)info->built_in_preset_ids[i] << (i == info->built_in_preset_ids.size() - 1 ? "" : ",");
		ss << "],\"custom_presets\":[";
		for (size_t i = 0; i < info->custom_presets.size(); ++i) {
			ss << "{\"id\":" << (int)info->custom_presets[i].id << ",\"name\":\"" << info->custom_presets[i].name << "\",\"values\":[";
			for (size_t j = 0; j < info->custom_presets[i].values.size(); ++j) ss << (int)info->custom_presets[i].values[j] << (j == info->custom_presets[i].values.size() - 1 ? "" : ",");
			ss << "]}"; if (i != info->custom_presets.size() - 1) ss << ",";
		}
		ss << "]}";
		snprintf(json_buffer, sizeof(json_buffer), "%s", ss.str().c_str());
	} else {
		snprintf(json_buffer, sizeof(json_buffer), "{}");
	}
	return json_buffer;
}

FFI_EXPORT void SetEqualizerPreset(int id) {
	if (IsConnected() && id >= 0 && id <= 255) {
		g_device->set_equalizer_preset(static_cast<uint8_t>(id));
	}
}

FFI_EXPORT void CreateOrUpdateCustomEq(int id, const char* name_utf8, const int* values, int len) {
	if (!IsConnected() || len != 10) return;
	CustomEqPreset p;
	p.id = static_cast<uint8_t>(id);
	p.name = std::string(name_utf8);
	for (int i = 0; i < len; ++i) {
		p.values.push_back(static_cast<int8_t>(values[i]));
	}
	g_device->create_or_update_custom_equalizer(p);
}

FFI_EXPORT void DeleteCustomEq(int id, const char* name_utf8, const int* values, int len) {
	if (!IsConnected() || len != 10) return;
	CustomEqPreset p;
	p.id = static_cast<uint8_t>(id);
	p.name = std::string(name_utf8);
	for (int i = 0; i < len; ++i) {
		p.values.push_back(static_cast<int8_t>(values[i]));
	}
	g_device->delete_custom_equalizer(p);
}

FFI_EXPORT void CreateFakePreset(int type, int id) {
	if (IsConnected()) {
		g_device->create_fake_preset(intToFakePreset(type), static_cast<uint8_t>(id));
	}
}

// --- Dual Connect ---
FFI_EXPORT const char* GetDualConnectDevices() {
	if (!IsConnected()) { snprintf(json_buffer, sizeof(json_buffer), "[]"); return json_buffer; }
	auto devices = g_device->get_dual_connect_devices();
	std::ostringstream ss;
	ss << "[";
	for (size_t i = 0; i < devices.size(); ++i) {
		ss << "{\"mac_address\":\"" << devices[i].mac_address << "\",\"name\":\"" << devices[i].name << "\",\"is_connected\":" << (devices[i].is_connected ? "true" : "false") << ",\"is_playing\":" << (devices[i].is_playing ? "true" : "false") << "}";
		if (i != devices.size() - 1) ss << ",";
	}
	ss << "]";
	snprintf(json_buffer, sizeof(json_buffer), "%s", ss.str().c_str());
	return json_buffer;
}
FFI_EXPORT void DualConnectAction(const char* mac_utf8, int code) {
	if (IsConnected() && code >= 0 && code <= 255) {
		g_device->dual_connect_action(std::string(mac_utf8), static_cast<uint8_t>(code));
	}
}

} // extern "C"