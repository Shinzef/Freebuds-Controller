#include "device.h"
#include "core/command_writer.h"
#include "protocol/huawei_commands.h"
#include <iostream>
#include <stdexcept>
#include <algorithm>
#include <iomanip> // For std::setw, etc. in MAC address formatting
#include <sstream> // For std::stringstream
#include <chrono>

// =================================================================
// Helpers
// =================================================================

// Helper to get a string from a vector of bytes
std::string to_str(const std::vector<uint8_t> &vec) { return std::string(vec.begin(), vec.end()); }

// Helper to map integer codes to GestureAction enum
GestureAction int_to_gesture_action(int code) {
	switch (static_cast<int8_t>(code)) {
		case 1: return GestureAction::PLAY_PAUSE;
		case 2: return GestureAction::NEXT_TRACK;
		case 7: return GestureAction::PREV_TRACK;
		case 0: return GestureAction::VOICE_ASSISTANT;
		case -1: return GestureAction::OFF;
		case 10: return GestureAction::SWITCH_ANC;
		default: return GestureAction::UNKNOWN;
	}
}

// Helper to map integer codes to AncCycleMode enum
AncCycleMode int_to_anc_cycle_mode(int code) {
	switch (static_cast<uint8_t>(code)) {
		case 1: return AncCycleMode::OFF_ON;
		case 2: return AncCycleMode::OFF_ON_AWARENESS;
		case 3: return AncCycleMode::ON_AWARENESS;
		case 4: return AncCycleMode::OFF_AWARENESS;
		default: return AncCycleMode::UNKNOWN;
	}
}

AncLevel int_to_anc_level(uint8_t mode_code, uint8_t level_code) {
	if (mode_code == 1) { // Cancellation mode
		switch (level_code) {
			case 1: return AncLevel::COMFORTABLE;
			case 0: return AncLevel::NORMAL_CANCELLATION;
			case 2: return AncLevel::ULTRA;
			case 3: return AncLevel::DYNAMIC;
		}
	} else if (mode_code == 2) { // Awareness mode
		switch (level_code) {
			case 1: return AncLevel::VOICE_BOOST;
			case 2: return AncLevel::NORMAL_AWARENESS;
		}
	}
	return AncLevel::UNKNOWN;
}

// =================================================================
// Device Class Implementation
// =================================================================

Device::Device(std::unique_ptr<IBluetoothSPPClient> bt_client)
	: m_client(std::move(bt_client)) {}

Device::~Device() = default;

bool Device::connect(const std::string &address, int port) {
	if (m_client->connect(address, port)) {
		m_writer = std::make_unique<CommandWriter>(*m_client);
		return true;
	}
	return false;
}

void Device::disconnect() { m_client->disconnect(); }
bool Device::is_connected() const { return m_client->is_connected(); }

// --- Write API Delegation (Complete) ---
void Device::set_anc_mode(AncMode m) { if (m_writer) m_writer->set_anc_mode(m); }
void Device::set_anc_level(AncLevel level) { if (m_writer) m_writer->set_anc_level(level); }
void Device::set_wear_detection(bool e) { if (m_writer) m_writer->set_wear_detection(e); }
void Device::set_low_latency(bool e) { if (m_writer) m_writer->set_low_latency(e); }
void Device::set_sound_quality_preference(SoundQualityPreference p) {
		if (m_writer) m_writer->set_sound_quality_preference(p == SoundQualityPreference::PRIORITIZE_QUALITY);
	}
void Device::set_double_tap_action(EarSide s, GestureAction a) { if (m_writer) m_writer->set_double_tap_action(s, a); }
void Device::set_triple_tap_action(EarSide s, GestureAction a) { if (m_writer) m_writer->set_triple_tap_action(s, a); }
void Device::set_swipe_action(GestureAction a) { if (m_writer) m_writer->set_swipe_action(a); }
void Device::set_long_tap_action(EarSide s, GestureAction a) { if (m_writer) m_writer->set_long_tap_action(s, a); }
void Device::set_long_tap_anc_cycle(EarSide s, AncCycleMode m) { if (m_writer) m_writer->set_long_tap_anc_cycle(s, m); }
void Device::set_incall_double_tap_action(GestureAction a) { if (m_writer) m_writer->set_incall_double_tap_action(a); }
void Device::set_equalizer_preset(uint8_t id) { if (m_writer) m_writer->set_equalizer_preset(id); }
void Device::create_or_update_custom_equalizer(const CustomEqPreset &p) { if (m_writer) m_writer->create_or_update_custom_equalizer(p); }
void Device::delete_custom_equalizer(const CustomEqPreset &p) { if (m_writer) m_writer->delete_custom_equalizer(p); }
void Device::create_fake_preset(FakePreset p, uint8_t id) { if (m_writer) m_writer->create_fake_preset(p, id); }
void Device::set_dual_connect_enabled(bool e) { if (m_writer) m_writer->set_dual_connect_enabled(e); }
void Device::set_dual_connect_preferred(const std::string &mac) { if (m_writer) m_writer->set_dual_connect_preferred(mac); }
void Device::dual_connect_action(const std::string &mac, uint8_t code) { if (m_writer) m_writer->dual_connect_action(mac, code); }

// --- Read API (Complete) ---
std::optional<DeviceInfo> Device::get_device_info() {
	auto request = HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_DEVICE_INFO_READ,
														{7, 9, 10, 15, 24});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_DEVICE_INFO_READ)) {
		return parse_device_info(*response);
	}
	return std::nullopt;
}

std::optional<BatteryInfo> Device::get_battery_info() {
	auto
		request = HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_BATTERY_READ, {1, 2, 3});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_BATTERY_READ)) {
		return parse_battery_info(*response);
	}
	return std::nullopt;
}

std::optional<GestureSettings> Device::get_all_gesture_settings() {
	GestureSettings settings;
	if (auto r =
		send_and_get_response(HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_DUAL_TAP_READ,
																   {1, 2, 4}),
							  HuaweiCommands::CMD_DUAL_TAP_READ))
		populate_gesture_settings(settings, *r);
	if (auto r =
		send_and_get_response(HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_TRIPLE_TAP_READ,
																   {1, 2}),
							  HuaweiCommands::CMD_TRIPLE_TAP_READ))
		populate_gesture_settings(settings, *r);
	if (auto r =
		send_and_get_response(HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_BASE,
																   {1, 2}),
							  HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_BASE))
		populate_gesture_settings(settings, *r);
	if (auto r =
		send_and_get_response(HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_ANC,
																   {1, 2}),
							  HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_ANC))
		populate_gesture_settings(settings, *r);
	if (auto r =
		send_and_get_response(HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_SWIPE_READ,
																   {1}),
							  HuaweiCommands::CMD_SWIPE_READ))
		populate_gesture_settings(settings, *r);
	return settings;
}

std::vector<DualConnectDevice> Device::get_dual_connect_devices() {
	std::vector<DualConnectDevice> devices;
	auto request =
		HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_DUAL_CONNECT_ENUMERATE, {1});
	// Enumerate returns multiple packets, so we can't use the helper
	if (m_client->send(request.to_bytes())) {
		for (const auto &bytes : m_client->receive_all()) {
			if (auto packet = HuaweiSppPacket::from_bytes(bytes)) {
				if (packet->command_id
					== bytes_to_u16(HuaweiCommands::CMD_DUAL_CONNECT_ENUMERATE[0],
									HuaweiCommands::CMD_DUAL_CONNECT_ENUMERATE[1])) {
					devices.push_back(parse_dual_connect_device(*packet));
				}
			}
		}
	}
	return devices;
}

std::optional<EqualizerInfo> Device::get_equalizer_info() {
	auto request =
		HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_EQUALIZER_READ, {2, 3, 8});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_EQUALIZER_READ)) {
		EqualizerInfo info;
		populate_equalizer_info(info, *response);
		return info;
	}
	return std::nullopt;
}

std::optional<AncStatus> Device::get_anc_status() {
	auto request = HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_ANC_READ, {1});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_ANC_READ)) {
		return parse_anc_status(*response);
	}
	return std::nullopt;
}

std::optional<bool> Device::get_wear_detection_status() {
	auto request = HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_AUTO_PAUSE_READ, {1});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_AUTO_PAUSE_READ)) {
		if (auto p = response->get_param(1); p && !p->empty()) {
			return (*p)[0] == 1;
		}
	}
	return std::nullopt;
}

std::optional<bool> Device::get_low_latency_status() {
	auto request = HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_LOW_LATENCY_READ, {2});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_LOW_LATENCY_READ)) {
		if (auto p = response->get_param(2); p && !p->empty()) {
			return (*p)[0] == 1;
		}
	}
	return std::nullopt;
}

std::optional<SoundQualityPreference> Device::get_sound_quality_preference() {
	auto
		request = HuaweiSppPacket::create_read_request(HuaweiCommands::CMD_SOUND_QUALITY_READ, {1});
	if (auto response = send_and_get_response(request, HuaweiCommands::CMD_SOUND_QUALITY_READ)) {
		if (auto p = response->get_param(2); p && !p->empty()) {
			return (*p)[0] == 1 ? SoundQualityPreference::PRIORITIZE_QUALITY
								: SoundQualityPreference::PRIORITIZE_CONNECTION;
		}
	}
	return std::nullopt;
}

// --- Private Helpers ---
std::optional<HuaweiSppPacket> Device::send_and_get_response(const HuaweiSppPacket& request, const std::array<uint8_t, 2>& expected_response_cmd) {
	// We expect the response to have the same command ID as the request.
	uint16_t expected_id = bytes_to_u16(expected_response_cmd[0], expected_response_cmd[1]);

	std::cout << "[DEVICE] Sending request for command 0x" << std::hex << request.command_id << " and waiting for response 0x" << expected_id << std::dec << std::endl;

	if (!m_client->send(request.to_bytes())) {
		std::cerr << "[DEVICE] ERROR: m_client->send() returned false." << std::endl;
		return std::nullopt;
	}

	// Instead of polling once, we now have a dedicated loop with a timeout.
	// This gives the system time to clear out old notifications and receive the correct packet.
	const int timeout_ms = 2000; // 2-second timeout.
	auto start_time = std::chrono::steady_clock::now();

	while (std::chrono::steady_clock::now() - start_time < std::chrono::milliseconds(timeout_ms)) {
		// The receive_all() function itself has a short internal timeout.
		// We call it repeatedly.
		auto responses_bytes = m_client->receive_all();

		if (!responses_bytes.empty()) {
			std::cout << "[DEVICE] Received " << responses_bytes.size() << " packet(s) from client." << std::endl;
		}

		// Now, iterate through all the packets we just received.
		for (const auto& bytes : responses_bytes) {
			if (auto packet = HuaweiSppPacket::from_bytes(bytes)) {
				// Check if this packet is the one we are looking for.
				if (packet->command_id == expected_id) {
					std::cout << "[DEVICE] SUCCESS: Found matching response packet for command 0x" << std::hex << expected_id << std::dec << std::endl;
					return packet; // Success! Return the correct packet.
				} else {
					// This is a valid packet, but not the one we want.
					// It's likely a notification. We log it and ignore it.
					std::cout << "[DEVICE] Ignoring unrelated packet for command 0x" << std::hex << packet->command_id << std::dec << std::endl;
				}
			}
		}
		// If we didn't find our packet, sleep for a very short duration
		// to prevent a busy-wait loop that hogs the CPU.
		std::this_thread::sleep_for(std::chrono::milliseconds(50));
	}

	// If we exit the loop, it means the 2-second timeout was reached.
	std::cerr << "[DEVICE] ERROR: Timed out after " << timeout_ms << "ms waiting for response to command 0x" << std::hex << expected_id << std::dec << std::endl;
	return std::nullopt;
}

// --- Private Parsers ---
DeviceInfo Device::parse_device_info(const HuaweiSppPacket &packet) {
	DeviceInfo info;
	if (auto p = packet.get_param(15)) info.model = to_str(*p);
	if (auto p = packet.get_param(10)) info.sub_model = to_str(*p);
	if (auto p = packet.get_param(7)) info.firmware_version = to_str(*p);
	if (auto p = packet.get_param(9)) info.serial_number = to_str(*p);
	// ... parse serials ...
	return info;
}

BatteryInfo Device::parse_battery_info(const HuaweiSppPacket &packet) {
	BatteryInfo info;
	if (auto p = packet.get_param(1); p && !p->empty()) info.global = (*p)[0];
	if (auto p = packet.get_param(2); p && p->size() >= 3) {
		info.left = (*p)[0];
		info.right = (*p)[1];
		info.case_level = (*p)[2];
	}
	if (auto p = packet.get_param(3); p && p->size() >= 3) {
		info.is_charging_case = (*p)[0] == 1;
		info.is_charging_left = (*p)[1] == 1;
		info.is_charging_right = (*p)[2] == 1;
	}
	return info;
}

void Device::populate_gesture_settings(GestureSettings &settings, const HuaweiSppPacket &packet) {
	if (packet.command_id == bytes_to_u16(HuaweiCommands::CMD_DUAL_TAP_READ[0],
										  HuaweiCommands::CMD_DUAL_TAP_READ[1])) {
		if (auto p = packet.get_param(1)) settings.double_tap_left = int_to_gesture_action((*p)[0]);
		if (auto p = packet.get_param(2))
			settings.double_tap_right = int_to_gesture_action((*p)[0]);
		if (auto p = packet.get_param(4))
			settings.double_tap_incall = int_to_gesture_action((*p)[0]);
	} else if (packet.command_id == bytes_to_u16(HuaweiCommands::CMD_TRIPLE_TAP_READ[0],
												 HuaweiCommands::CMD_TRIPLE_TAP_READ[1])) {
		if (auto p = packet.get_param(1)) settings.triple_tap_left = int_to_gesture_action((*p)[0]);
		if (auto p = packet.get_param(2))
			settings.triple_tap_right = int_to_gesture_action((*p)[0]);
	} else if (packet.command_id == bytes_to_u16(HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_BASE[0],
												 HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_BASE[1])) {
		if (auto p = packet.get_param(1)) settings.long_tap_left = int_to_gesture_action((*p)[0]);
		if (auto p = packet.get_param(2)) settings.long_tap_right = int_to_gesture_action((*p)[0]);
	} else if (packet.command_id == bytes_to_u16(HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_ANC[0],
												 HuaweiCommands::CMD_LONG_TAP_SPLIT_READ_ANC[1])) {
		if (auto p = packet.get_param(1))
			settings.long_tap_anc_cycle_left = int_to_anc_cycle_mode((*p)[0]);
		if (auto p = packet.get_param(2))
			settings.long_tap_anc_cycle_right = int_to_anc_cycle_mode((*p)[0]);
	} else if (packet.command_id
		== bytes_to_u16(HuaweiCommands::CMD_SWIPE_READ[0], HuaweiCommands::CMD_SWIPE_READ[1])) {
		if (auto p = packet.get_param(1))
			settings.swipe_action = ((*p)[0] == 0) ? GestureAction::CHANGE_VOLUME
												   : GestureAction::OFF;
	}
}

DualConnectDevice Device::parse_dual_connect_device(const HuaweiSppPacket &packet) {
	DualConnectDevice device;
	if (auto p = packet.get_param(9)) device.name = to_str(*p);
	if (auto p = packet.get_param(4)) {
		std::stringstream mac_ss;
		for (size_t i = 0; i < p->size(); ++i) {
			mac_ss << std::hex << std::setfill('0') << std::setw(2) << (int)(*p)[i];
			if (i < p->size() - 1) mac_ss << ":";
		}
		device.mac_address = mac_ss.str();
	}
	if (auto p = packet.get_param(5); !p->empty()) {
		device.is_connected = ((*p)[0] > 0);
		device.is_playing = ((*p)[0] == 9);
	}
	if (auto p = packet.get_param(7); !p->empty()) device.is_preferred = ((*p)[0] == 1);
	if (auto p = packet.get_param(8); !p->empty()) device.can_auto_connect = ((*p)[0] == 1);
	return device;
}

void Device::populate_equalizer_info(EqualizerInfo &info, const HuaweiSppPacket &packet) {
	if (packet.command_id != bytes_to_u16(HuaweiCommands::CMD_EQUALIZER_READ[0],
										  HuaweiCommands::CMD_EQUALIZER_READ[1]))
		return;

	if (auto p = packet.get_param(2); !p->empty()) info.current_preset_id = (*p)[0];
	if (auto p = packet.get_param(3)) info.built_in_preset_ids = *p;
	if (auto p = packet.get_param(8); !p->empty()) {
		const auto &blob = *p;
		size_t pos = 0;
		while (pos < blob.size()) {
			if (pos + 2 > blob.size()) break;
			CustomEqPreset preset;
			preset.id = blob[pos];
			uint8_t num_values = blob[pos + 1];

			// Ensure we don't read past the end of the blob
			if (pos + 2 + num_values > blob.size()) break;

			size_t name_start = pos + 2 + num_values;
			if (name_start > blob.size()) break;

			size_t name_end = name_start;
			while (name_end < blob.size() && blob[name_end] != '\0') {
				name_end++;
			}
			preset.name = std::string(blob.begin() + name_start, blob.begin() + name_end);

			preset.values.reserve(num_values);
			for (size_t i = 0; i < num_values; ++i) {
				preset.values.push_back(static_cast<int8_t>(blob[pos + 2 + i]));
			}

			// --- THE FIX IS HERE ---
			// 1. The unconditional `push_back` has been DELETED.
			// 2. We now ONLY add the preset if it passes the check.
			if (!preset.name.empty() && preset.id != 0) {
				info.custom_presets.push_back(preset);
			}

			// The +1 accounts for the null terminator of the name string
			pos = name_end + 1;
		}
	}
}

AncStatus Device::parse_anc_status(const HuaweiSppPacket &packet) {
	AncStatus status;
	if (auto p = packet.get_param(1); p && p->size() == 2) {
		uint8_t level_code = (*p)[0];
		uint8_t mode_code = (*p)[1];

		// Add debugging
		std::cout << "Raw packet values - level_code: " << (int)level_code << ", mode_code: "
				  << (int)mode_code << std::endl;

		switch (mode_code) {
			case 0: status.mode = AncMode::NORMAL;
				break;
			case 1: status.mode = AncMode::CANCELLATION;
				break;
			case 2: status.mode = AncMode::AWARENESS;
				break;
			default: status.mode = AncMode::UNKNOWN;
				break;
		}

		status.level = int_to_anc_level(mode_code, level_code);

		std::cout << "Parsed AncStatus - mode: " << (int)status.mode << ", level: "
				  << (int)status.level << std::endl;
	}
	return status;
}