#pragma once
#include <array>
#include <cstdint>

namespace HuaweiCommands {
    // --- Core Device Information ---
    constexpr std::array<uint8_t, 2> CMD_DEVICE_INFO_READ = {0x01, 0x07};

    // --- Battery ---
    constexpr std::array<uint8_t, 2> CMD_BATTERY_READ = {0x01, 0x08};
    constexpr std::array<uint8_t, 2> CMD_BATTERY_NOTIFY = {0x01, 0x27}; // Device sends this automatically

    // --- ANC (Active Noise Cancellation) ---
    constexpr std::array<uint8_t, 2> CMD_ANC_READ = {0x2b, 0x2a};
    constexpr std::array<uint8_t, 2> CMD_ANC_WRITE = {0x2b, 0x04};
    constexpr std::array<uint8_t, 2> CMD_ANC_NOTIFY = {0x2b, 0x03}; // Device sends on physical button press

    // --- Gestures ---
    constexpr std::array<uint8_t, 2> CMD_DUAL_TAP_READ = {0x01, 0x20};
    constexpr std::array<uint8_t, 2> CMD_DUAL_TAP_WRITE = {0x01, 0x1f};

    constexpr std::array<uint8_t, 2> CMD_TRIPLE_TAP_READ = {0x01, 0x26};
    constexpr std::array<uint8_t, 2> CMD_TRIPLE_TAP_WRITE = {0x01, 0x25};

    constexpr std::array<uint8_t, 2> CMD_LONG_TAP_SPLIT_READ_BASE = {0x2b, 0x17};
    constexpr std::array<uint8_t, 2> CMD_LONG_TAP_SPLIT_WRITE_BASE = {0x2b, 0x16};
    constexpr std::array<uint8_t, 2> CMD_LONG_TAP_SPLIT_READ_ANC = {0x2b, 0x19};
    constexpr std::array<uint8_t, 2> CMD_LONG_TAP_SPLIT_WRITE_ANC = {0x2b, 0x18};

    constexpr std::array<uint8_t, 2> CMD_SWIPE_READ = {0x2b, 0x1f};
    constexpr std::array<uint8_t, 2> CMD_SWIPE_WRITE = {0x2b, 0x1e};

    // --- Device Configuration ---
    constexpr std::array<uint8_t, 2> CMD_AUTO_PAUSE_READ = {0x2b, 0x11};
    constexpr std::array<uint8_t, 2> CMD_AUTO_PAUSE_WRITE = {0x2b, 0x10};

    // From: handler/state_in_ear.py (This is a notification from the device)
    constexpr std::array<uint8_t, 2> CMD_IN_EAR_STATUS_NOTIFY = {0x2b, 0x03};

    // --- Sound Settings ---
    constexpr std::array<uint8_t, 2> CMD_SOUND_QUALITY_READ = {0x2b, 0xa3};
    constexpr std::array<uint8_t, 2> CMD_SOUND_QUALITY_WRITE = {0x2b, 0xa2};

    constexpr std::array<uint8_t, 2> CMD_LOW_LATENCY_READ = {0x2b, 0x6c};
    constexpr std::array<uint8_t, 2> CMD_LOW_LATENCY_WRITE = {0x2b, 0x6c}; // Same command for read/write

    constexpr std::array<uint8_t, 2> CMD_EQUALIZER_READ = {0x2b, 0x4a};
    constexpr std::array<uint8_t, 2> CMD_EQUALIZER_WRITE = {0x2b, 0x49};

    // --- Dual Connect ---
    constexpr std::array<uint8_t, 2> CMD_DUAL_CONNECT_ENABLED_READ = {0x2b, 0x2f};
    constexpr std::array<uint8_t, 2> CMD_DUAL_CONNECT_ENABLED_WRITE = {0x2b, 0x2e};
    constexpr std::array<uint8_t, 2> CMD_DUAL_CONNECT_ENUMERATE = {0x2b, 0x31};
    constexpr std::array<uint8_t, 2> CMD_DUAL_CONNECT_PREFERRED_WRITE = {0x2b, 0x32};
    constexpr std::array<uint8_t, 2> CMD_DUAL_CONNECT_EXECUTE = {0x2b, 0x33}; // For connect/disconnect/unpair
    constexpr std::array<uint8_t, 2> CMD_DUAL_CONNECT_CHANGE_EVENT = {0x2b, 0x36}; // Notification

    // --- Service ---
    constexpr std::array<uint8_t, 2> CMD_LANGUAGE_READ = {0x0c, 0x02};
    constexpr std::array<uint8_t, 2> CMD_LANGUAGE_WRITE = {0x0c, 0x01};
}