#pragma once

#include <string>
#include <vector>
#include <cstdint>

// --- Enums for Commands ---

enum class AncMode {
    NORMAL,
    CANCELLATION,
    AWARENESS,
    UNKNOWN
};

enum class AncLevel {
    // Cancellation Levels
    COMFORTABLE,
    NORMAL_CANCELLATION,
    ULTRA,
    DYNAMIC,
    // Awareness Levels
    VOICE_BOOST,
    NORMAL_AWARENESS,
    UNKNOWN
};

enum class GestureAction {
    PLAY_PAUSE, NEXT_TRACK, PREV_TRACK, VOICE_ASSISTANT, OFF,
    CHANGE_VOLUME,
    SWITCH_ANC,
    ANSWER_CALL,
    UNKNOWN
};

enum class AncCycleMode {
    OFF_ON, OFF_ON_AWARENESS, ON_AWARENESS, OFF_AWARENESS, UNKNOWN
};

enum class EarSide {
    LEFT,
    RIGHT,
    BOTH
};

enum class SoundQualityPreference {
    PRIORITIZE_CONNECTION,
    PRIORITIZE_QUALITY
};

enum class FakePreset { SYMPHONY, HI_FI_LIVE, UNKNOWN };


// --- Data Structures for Return Values ---

struct BatteryInfo {
    int left = 0;
    int right = 0;
    int case_level = 0;
    int global = 0; // For non-TWS or as an overall value
    bool is_charging_case = false;
    bool is_charging_left = false;
    bool is_charging_right = false;
};

struct DeviceInfo {
    std::string model;
    std::string sub_model;
    std::string firmware_version;
    std::string serial_number;
    std::string left_serial;
    std::string right_serial;
};

struct DualConnectDevice {
    std::string mac_address;
    std::string name;
    bool is_connected = false;
    bool is_playing = false;
    bool is_preferred = false;
    bool can_auto_connect = false;
};

struct CustomEqPreset {
    uint8_t id = 0;
    std::string name;
    std::vector<int8_t> values; // 10 values from -60 to 60
};

struct GestureSettings {
    GestureAction double_tap_left = GestureAction::UNKNOWN;
    GestureAction double_tap_right = GestureAction::UNKNOWN;
    GestureAction double_tap_incall = GestureAction::UNKNOWN;
    GestureAction triple_tap_left = GestureAction::UNKNOWN;
    GestureAction triple_tap_right = GestureAction::UNKNOWN;
    GestureAction long_tap_left = GestureAction::UNKNOWN;
    GestureAction long_tap_right = GestureAction::UNKNOWN;
    AncCycleMode long_tap_anc_cycle_left = AncCycleMode::UNKNOWN;
    AncCycleMode long_tap_anc_cycle_right = AncCycleMode::UNKNOWN;
    GestureAction swipe_action = GestureAction::UNKNOWN;
};

struct EqualizerInfo {
    uint8_t current_preset_id = 0;
    std::vector<uint8_t> built_in_preset_ids;
    // Now this is valid because CustomEqPreset is defined above
    std::vector<CustomEqPreset> custom_presets;
};

struct AncStatus {
    AncMode mode = AncMode::UNKNOWN;
    AncLevel level = AncLevel::UNKNOWN; // Only valid when mode is CANCELLATION or AWARENESS
};