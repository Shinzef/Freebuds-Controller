#include "command_writer.h"
#include "protocol/huawei_commands.h"
#include "protocol/huawei_packet.h"
#include "core/debug_log.h"
#include <iostream>
#include <stdexcept>

// =================================================================
// Helper Mappers (Enum to Integer)
// =================================================================

int gesture_action_to_int(GestureAction action) {
    switch (action) {
        case GestureAction::PLAY_PAUSE:     return 1;
        case GestureAction::NEXT_TRACK:     return 2;
        case GestureAction::PREV_TRACK:     return 7;
        case GestureAction::VOICE_ASSISTANT: return 0;
        case GestureAction::OFF:            return -1;
        case GestureAction::CHANGE_VOLUME:  return 0; // For swipe
        case GestureAction::SWITCH_ANC:     return 10; // For long-tap
        case GestureAction::ANSWER_CALL:    return 0; // For in-call
        default: throw std::invalid_argument("Unknown gesture action");
    }
}

int anc_cycle_to_int(AncCycleMode mode) {
    switch (mode) {
        case AncCycleMode::OFF_ON:              return 1;
        case AncCycleMode::OFF_ON_AWARENESS:    return 2;
        case AncCycleMode::ON_AWARENESS:        return 3;
        case AncCycleMode::OFF_AWARENESS:       return 4;
        default: throw std::invalid_argument("Unknown ANC cycle mode");
    }
}

// This function returns a pair of {mode, level}
std::pair<uint8_t, uint8_t> anc_level_to_int(AncLevel level) {
    switch (level) {
        // Cancellation levels: {mode, level}
        case AncLevel::COMFORTABLE:         return {1, 1};
        case AncLevel::NORMAL_CANCELLATION: return {1, 0};
        case AncLevel::ULTRA:               return {1, 2};
        case AncLevel::DYNAMIC:             return {1, 3};
            // Awareness levels: {mode, level}
        case AncLevel::VOICE_BOOST:         return {2, 1};
        case AncLevel::NORMAL_AWARENESS:    return {2, 2};
        default: return {0, 0}; // Invalid
    }
}

CommandWriter::CommandWriter(IBluetoothSPPClient& client) : m_client(client), m_running(true) {
	m_worker_thread = std::thread(&CommandWriter::process_queue, this); // Start the worker thread upon construction
}

CommandWriter::~CommandWriter() {
	m_command_queue.stop(); // Signal the queue to stop and wake up the worker thread
	// Wait for the worker thread to finish its current task and exit
	if (m_worker_thread.joinable()) {
		m_worker_thread.join();
	}
}

void CommandWriter::process_queue() {
	std::function<void()> task;
	// This loop will block on wait_and_pop until a task is available or the queue is stopped.
	while (m_command_queue.wait_and_pop(task)) {
		task();
	}
}

void CommandWriter::send_and_log(const HuaweiSppPacket& request, const std::string& description) {
	m_command_queue.push([this, request, description] {
	 std::cout << ">>> [Worker Thread] Sending " << description << " request..." << std::endl;
	      if (m_client.send(request.to_bytes())) {
			  std::cout << "<<< [Worker Thread] Command sent successfully." << std::endl;
			  // The response consumption should also happen on the worker thread.
			  m_client.receive_all();
		  } else {
			  std::cerr << "!!! [Worker Thread] Failed to send " << description << " request." << std::endl;
		  }
	});
}

// --- ANC / Config ---
void CommandWriter::set_anc_mode(AncMode mode) {
    if (mode == AncMode::UNKNOWN) return;
    uint8_t mode_val = static_cast<uint8_t>(mode);

    std::vector<uint8_t> payload = {mode_val, 0xFF};

    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_ANC_WRITE, 1, payload);
    send_and_log(request, "Set ANC Mode");
}

// This method sets the specific level within a mode.
void CommandWriter::set_anc_level(AncLevel level) {
    if (level == AncLevel::UNKNOWN) return;

    // The Python driver shows that for setting a level, the payload must be [mode, level].
    // We get the {mode, level} pair from our helper.
    auto [mode_code, level_code] = anc_level_to_int(level);

    std::cout << "Setting ANC level - enum: " << static_cast<int>(level)
              << ", mode_code: " << static_cast<int>(mode_code)
              << ", level_code: " << static_cast<int>(level_code) << std::endl;

    // The payload must be {mode, level}.
    std::vector<uint8_t> payload = {mode_code, level_code};

    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_ANC_WRITE, 1, payload
    );

    std::cout << "Sending ANC level packet with payload: ["
              << static_cast<int>(payload[0]) << ", "
              << static_cast<int>(payload[1]) << "]" << std::endl;
    send_and_log(request, "Set ANC Level");
}

void CommandWriter::set_wear_detection(bool enable) {
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_AUTO_PAUSE_WRITE, 1, {static_cast<uint8_t>(enable ? 1 : 0)});
    send_and_log(request, "Set Wear Detection");

}

void CommandWriter::set_low_latency(bool enable) {
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_LOW_LATENCY_WRITE, 1, {static_cast<uint8_t>(enable ? 1 : 0)});
    send_and_log(request, "Set Low Latency");
}

void CommandWriter::set_sound_quality_preference(bool prioritize_quality) {
    uint8_t value = prioritize_quality ? 1 : 0;
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_SOUND_QUALITY_WRITE, 1, {value}
    );
    send_and_log(request, "Set Sound Quality Preference");
}

// --- Gestures ---
void CommandWriter::set_double_tap_action(EarSide side, GestureAction action) {
    if (action == GestureAction::UNKNOWN || side == EarSide::BOTH) return;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_DUAL_TAP_WRITE, param_id, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set Double Tap");
}

void CommandWriter::set_triple_tap_action(EarSide side, GestureAction action) {
    if (action == GestureAction::UNKNOWN || side == EarSide::BOTH) return;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_TRIPLE_TAP_WRITE, param_id, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set Triple Tap");
}

void CommandWriter::set_swipe_action(GestureAction action) {
    if (action != GestureAction::CHANGE_VOLUME && action != GestureAction::OFF) return;
    int8_t action_code = (action == GestureAction::CHANGE_VOLUME)
                         ? static_cast<int8_t>(gesture_action_to_int(GestureAction::CHANGE_VOLUME))
                         : static_cast<int8_t>(gesture_action_to_int(GestureAction::OFF));

    auto request = HuaweiSppPacket(bytes_to_u16(HuaweiCommands::CMD_SWIPE_WRITE[0], HuaweiCommands::CMD_SWIPE_WRITE[1]));
    request.parameters[1] = { static_cast<uint8_t>(action_code) };
    request.parameters[2] = { static_cast<uint8_t>(action_code) };
    send_and_log(request, "Set Swipe Action");
}

void CommandWriter::set_long_tap_action(EarSide side, GestureAction action) {
    if (action != GestureAction::SWITCH_ANC && action != GestureAction::OFF) return;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_LONG_TAP_SPLIT_WRITE_BASE, param_id, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set Long Tap Action");
}

void CommandWriter::set_long_tap_anc_cycle(EarSide side, AncCycleMode cycle_mode) {
    if (cycle_mode == AncCycleMode::UNKNOWN) return;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    uint8_t cycle_code = static_cast<uint8_t>(anc_cycle_to_int(cycle_mode));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_LONG_TAP_SPLIT_WRITE_ANC, param_id, {cycle_code});
    send_and_log(request, "Set Long Tap ANC Cycle");
}

void CommandWriter::set_incall_double_tap_action(GestureAction action) {
    if (action != GestureAction::ANSWER_CALL && action != GestureAction::OFF) return;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_DUAL_TAP_WRITE, 4, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set In-Call Double Tap");
}

// --- Equalizer ---
void CommandWriter::set_equalizer_preset(uint8_t preset_id) {
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_EQUALIZER_WRITE, 1, {preset_id}
    );
    send_and_log(request, "Set Built-in Equalizer Preset");
}

void CommandWriter::create_or_update_custom_equalizer(const CustomEqPreset& preset) {
    if (preset.values.size() != 10) {
        std::cerr << "Custom EQ preset must have exactly 10 values." << std::endl;
        return;
    }
    std::vector<uint8_t> values_as_uint;
    values_as_uint.reserve(preset.values.size());
    for(int8_t val : preset.values) {
        values_as_uint.push_back(static_cast<uint8_t>(val));
    }
    auto request = HuaweiSppPacket(bytes_to_u16(HuaweiCommands::CMD_EQUALIZER_WRITE[0], HuaweiCommands::CMD_EQUALIZER_WRITE[1]));
    request.parameters[1] = { preset.id };
    request.parameters[2] = { static_cast<uint8_t>(values_as_uint.size()) };
    request.parameters[3] = values_as_uint;
    request.parameters[4] = std::vector<uint8_t>(preset.name.begin(), preset.name.end());
    request.parameters[5] = { 1 };
    send_and_log(request, "Create/Update Custom Equalizer");
}

void CommandWriter::delete_custom_equalizer(const CustomEqPreset& preset) {
    if (preset.values.size() != 10) {
        std::cerr << "Cannot delete EQ preset with invalid values." << std::endl;
        return;
    }
    std::vector<uint8_t> values_as_uint;
    values_as_uint.reserve(preset.values.size());
    for(int8_t val : preset.values) {
        values_as_uint.push_back(static_cast<uint8_t>(val));
    }

    auto request = HuaweiSppPacket(bytes_to_u16(HuaweiCommands::CMD_EQUALIZER_WRITE[0], HuaweiCommands::CMD_EQUALIZER_WRITE[1]));
    request.parameters[1] = { preset.id };
    request.parameters[2] = { static_cast<uint8_t>(values_as_uint.size()) };
    request.parameters[3] = values_as_uint;
    request.parameters[4] = std::vector<uint8_t>(preset.name.begin(), preset.name.end());

    // The ONLY difference from create_or_update is this action code: '2' means DELETE.
    request.parameters[5] = { 2 };

    send_and_log(request, "Delete Custom Equalizer (Correct Payload)");
}

void CommandWriter::create_fake_preset(FakePreset preset_type, uint8_t new_id) {
    CustomEqPreset preset;
    preset.id = new_id;

    if (preset_type == FakePreset::SYMPHONY) {
        preset.name = "Symphony";
        preset.values = {15, 15, 10, -5, 15, 25, 15, -5, 50, 45};
    } else if (preset_type == FakePreset::HI_FI_LIVE) {
        preset.name = "Hi-Fi Live";
        preset.values = {-5, 20, 30, 10, 0, 0, -25, -10, 10, 0};
    } else {
        return;
    }

    std::cout << "Creating '" << preset.name << "' as a custom preset with ID " << (int)new_id << "..." << std::endl;
    return create_or_update_custom_equalizer(preset);
}

// --- Dual-Connect Methods ---
void CommandWriter::set_dual_connect_enabled(bool enable) {
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_DUAL_CONNECT_ENABLED_WRITE, 1, {static_cast<uint8_t>(enable ? 1 : 0)}
    );
    send_and_log(request, "Set Dual-Connect Enabled");
}

void CommandWriter::set_dual_connect_preferred(const std::string& mac_address) {
    if (mac_address.length() != 12) return;
    std::vector<uint8_t> mac_bytes;
    for(size_t i = 0; i < mac_address.length(); i += 2) {
        mac_bytes.push_back(static_cast<uint8_t>(std::stoul(mac_address.substr(i, 2), nullptr, 16)));
    }
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_DUAL_CONNECT_PREFERRED_WRITE, 1, mac_bytes
    );
    send_and_log(request, "Set Preferred Device");
}

void CommandWriter::dual_connect_action(const std::string& mac_address, uint8_t action_code) {
    if (mac_address.length() != 12) return;
    std::vector<uint8_t> mac_bytes;
    for(size_t i = 0; i < mac_address.length(); i += 2) {
        mac_bytes.push_back(static_cast<uint8_t>(std::stoul(mac_address.substr(i, 2), nullptr, 16)));
    }
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_DUAL_CONNECT_EXECUTE, action_code, mac_bytes
    );
    send_and_log(request, "Dual-Connect Action");
}