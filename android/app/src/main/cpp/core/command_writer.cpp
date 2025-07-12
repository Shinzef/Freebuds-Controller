#include "command_writer.h"
#include "protocol/huawei_commands.h"
#include "protocol/huawei_packet.h"
#include <iostream>
#include <stdexcept>

// =================================================================
// Helper Mappers (Enum to Integer)
// =================================================================

// Based on openfreebuds/driver/huawei/handler/abstract/multi_tap.py
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

// Based on openfreebuds/driver/huawei/handler/action_long_tap_split.py
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

// =================================================================
// CommandWriter Implementation
// =================================================================

CommandWriter::CommandWriter(IBluetoothSPPClient& client) : m_client(client) {}

void CommandWriter::send_and_log(const HuaweiSppPacket& request, const std::string& description) {
    std::cout << ">>> Sending " << description << " request..." << std::endl;
    if (m_client.send(request.to_bytes())) {
        std::cout << "<<< Command sent successfully." << std::endl;
        m_client.receive_all(); // Consume response
    } else {
        std::cerr << "!!! Failed to send " << description << " request." << std::endl;
    }
}

// --- ANC / Config ---
bool CommandWriter::set_anc_mode(AncMode mode) {
    if (mode == AncMode::UNKNOWN) return false;
    uint8_t mode_val = static_cast<uint8_t>(mode);

    // --- FIX ---
    // The payload must be in the format {level, mode}.
    // For a mode change, the level is 0xFF, which means "don't change level."
    std::vector<uint8_t> payload = {mode_val, 0xFF};

    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_ANC_WRITE, 1, payload);
    send_and_log(request, "Set ANC Mode");
    return true;
}

// This method sets the specific level within a mode.
// This method sets the specific level within a mode.
bool CommandWriter::set_anc_level(AncLevel level) {
    if (level == AncLevel::UNKNOWN) return false;

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
    // --- FIX END ---

    send_and_log(request, "Set ANC Level");
    return true;
}

bool CommandWriter::set_wear_detection(bool enable) {
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_AUTO_PAUSE_WRITE, 1, {static_cast<uint8_t>(enable ? 1 : 0)});
    send_and_log(request, "Set Wear Detection");
    return true;
}

bool CommandWriter::set_low_latency(bool enable) {
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_LOW_LATENCY_WRITE, 1, {static_cast<uint8_t>(enable ? 1 : 0)});
    send_and_log(request, "Set Low Latency");
    return true;
}

bool CommandWriter::set_sound_quality_preference(bool prioritize_quality) {
    uint8_t value = prioritize_quality ? 1 : 0;
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_SOUND_QUALITY_WRITE, 1, {value}
    );
    send_and_log(request, "Set Sound Quality Preference");
    return true;
}

// --- Gestures ---
bool CommandWriter::set_double_tap_action(EarSide side, GestureAction action) {
    if (action == GestureAction::UNKNOWN || side == EarSide::BOTH) return false;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_DUAL_TAP_WRITE, param_id, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set Double Tap");
    return true;
}

bool CommandWriter::set_triple_tap_action(EarSide side, GestureAction action) {
    if (action == GestureAction::UNKNOWN || side == EarSide::BOTH) return false;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_TRIPLE_TAP_WRITE, param_id, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set Triple Tap");
    return true;
}

bool CommandWriter::set_swipe_action(GestureAction action) {
    if (action != GestureAction::CHANGE_VOLUME && action != GestureAction::OFF) return false;
    int8_t action_code = (action == GestureAction::CHANGE_VOLUME)
                         ? static_cast<int8_t>(gesture_action_to_int(GestureAction::CHANGE_VOLUME))
                         : static_cast<int8_t>(gesture_action_to_int(GestureAction::OFF));

    auto request = HuaweiSppPacket(bytes_to_u16(HuaweiCommands::CMD_SWIPE_WRITE[0], HuaweiCommands::CMD_SWIPE_WRITE[1]));
    request.parameters[1] = { static_cast<uint8_t>(action_code) };
    request.parameters[2] = { static_cast<uint8_t>(action_code) };
    send_and_log(request, "Set Swipe Action");
    return true;
}

bool CommandWriter::set_long_tap_action(EarSide side, GestureAction action) {
    if (action != GestureAction::SWITCH_ANC && action != GestureAction::OFF) return false;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_LONG_TAP_SPLIT_WRITE_BASE, param_id, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set Long Tap Action");
    return true;
}

bool CommandWriter::set_long_tap_anc_cycle(EarSide side, AncCycleMode cycle_mode) {
    if (cycle_mode == AncCycleMode::UNKNOWN) return false;
    uint8_t param_id = (side == EarSide::LEFT) ? 1 : 2;
    uint8_t cycle_code = static_cast<uint8_t>(anc_cycle_to_int(cycle_mode));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_LONG_TAP_SPLIT_WRITE_ANC, param_id, {cycle_code});
    send_and_log(request, "Set Long Tap ANC Cycle");
    return true;
}

bool CommandWriter::set_incall_double_tap_action(GestureAction action) {
    if (action != GestureAction::ANSWER_CALL && action != GestureAction::OFF) return false;
    int8_t action_code = static_cast<int8_t>(gesture_action_to_int(action));
    auto request = HuaweiSppPacket::create_write_request(HuaweiCommands::CMD_DUAL_TAP_WRITE, 4, {static_cast<uint8_t>(action_code)});
    send_and_log(request, "Set In-Call Double Tap");
    return true;
}

// --- Equalizer ---
bool CommandWriter::set_equalizer_preset(uint8_t preset_id) {
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_EQUALIZER_WRITE, 1, {preset_id}
    );
    send_and_log(request, "Set Built-in Equalizer Preset");
    return true;
}

bool CommandWriter::create_or_update_custom_equalizer(const CustomEqPreset& preset) {
    if (preset.values.size() != 10) {
        std::cerr << "Custom EQ preset must have exactly 10 values." << std::endl;
        return false;
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
    return true;
}

bool CommandWriter::delete_custom_equalizer(uint8_t preset_id) {
    auto request = HuaweiSppPacket(bytes_to_u16(HuaweiCommands::CMD_EQUALIZER_WRITE[0], HuaweiCommands::CMD_EQUALIZER_WRITE[1]));
    request.parameters[1] = { preset_id };
    request.parameters[5] = { 2 };
    send_and_log(request, "Delete Custom Equalizer");
    return true;
}

bool CommandWriter::create_fake_preset(FakePreset preset_type, uint8_t new_id) {
    CustomEqPreset preset;
    preset.id = new_id;

    if (preset_type == FakePreset::SYMPHONY) {
        preset.name = "Symphony";
        preset.values = {15, 15, 10, -5, 15, 25, 15, -5, 50, 45};
    } else if (preset_type == FakePreset::HI_FI_LIVE) {
        preset.name = "Hi-Fi Live";
        preset.values = {-5, 20, 30, 10, 0, 0, -25, -10, 10, 0};
    } else {
        return false;
    }

    std::cout << "Creating '" << preset.name << "' as a custom preset with ID " << (int)new_id << "..." << std::endl;
    return create_or_update_custom_equalizer(preset);
}

// --- Dual-Connect Methods ---
bool CommandWriter::set_dual_connect_enabled(bool enable) {
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_DUAL_CONNECT_ENABLED_WRITE, 1, {static_cast<uint8_t>(enable ? 1 : 0)}
    );
    send_and_log(request, "Set Dual-Connect Enabled");
    return true;
}

bool CommandWriter::set_dual_connect_preferred(const std::string& mac_address) {
    if (mac_address.length() != 12) return false;
    std::vector<uint8_t> mac_bytes;
    for(size_t i = 0; i < mac_address.length(); i += 2) {
        mac_bytes.push_back(static_cast<uint8_t>(std::stoul(mac_address.substr(i, 2), nullptr, 16)));
    }
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_DUAL_CONNECT_PREFERRED_WRITE, 1, mac_bytes
    );
    send_and_log(request, "Set Preferred Device");
    return true;
}

bool CommandWriter::dual_connect_action(const std::string& mac_address, uint8_t action_code) {
    if (mac_address.length() != 12) return false;
    std::vector<uint8_t> mac_bytes;
    for(size_t i = 0; i < mac_address.length(); i += 2) {
        mac_bytes.push_back(static_cast<uint8_t>(std::stoul(mac_address.substr(i, 2), nullptr, 16)));
    }
    auto request = HuaweiSppPacket::create_write_request(
            HuaweiCommands::CMD_DUAL_CONNECT_EXECUTE, action_code, mac_bytes
    );
    send_and_log(request, "Dual-Connect Action");
    return true;
}