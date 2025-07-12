#pragma once

#include "platform/bluetooth_interface.h"
#include "protocol/huawei_packet.h"
#include "core/types.h"
#include <memory>
#include <optional>
#include <vector>
#include <string>

class CommandWriter;

class Device {
public:
    Device(std::unique_ptr<IBluetoothSPPClient> bt_client);
    ~Device();

    bool connect(const std::string& address, int port = 1);
    void disconnect();
    bool is_connected() const;

    // --- Read API ---
    std::optional<DeviceInfo> get_device_info();
    std::optional<BatteryInfo> get_battery_info();
    std::optional<GestureSettings> get_all_gesture_settings();
    std::vector<DualConnectDevice> get_dual_connect_devices();
    std::optional<EqualizerInfo> get_equalizer_info();
    std::optional<AncStatus> get_anc_status();
    std::optional<bool> get_wear_detection_status();
    std::optional<bool> get_low_latency_status();
    std::optional<SoundQualityPreference> get_sound_quality_preference();

    // --- Write API ---
    bool set_anc_mode(AncMode mode);
    bool set_anc_level(AncLevel level);
    bool set_wear_detection(bool enable);
    bool set_low_latency(bool enable);
    bool set_sound_quality_preference(SoundQualityPreference pref);
    bool set_double_tap_action(EarSide side, GestureAction action);
    bool set_triple_tap_action(EarSide side, GestureAction action);
    bool set_swipe_action(GestureAction action);
    bool set_long_tap_action(EarSide side, GestureAction action);
    bool set_long_tap_anc_cycle(EarSide side, AncCycleMode cycle_mode);
    bool set_incall_double_tap_action(GestureAction action);
    bool set_equalizer_preset(uint8_t preset_id);
    bool create_or_update_custom_equalizer(const CustomEqPreset& preset);
    bool delete_custom_equalizer(uint8_t preset_id);
    bool create_fake_preset(FakePreset preset, uint8_t new_id);
    bool set_dual_connect_enabled(bool enable);
    bool set_dual_connect_preferred(const std::string& mac_address);
    bool dual_connect_action(const std::string& mac_address, uint8_t action_code);

private:
    std::unique_ptr<IBluetoothSPPClient> m_client;
    std::unique_ptr<CommandWriter> m_writer;

    std::optional<HuaweiSppPacket> send_and_get_response(const HuaweiSppPacket& request, const std::array<uint8_t, 2>& expected_response_cmd);

    DeviceInfo parse_device_info(const HuaweiSppPacket& packet);
    BatteryInfo parse_battery_info(const HuaweiSppPacket& packet);
    void populate_gesture_settings(GestureSettings& settings, const HuaweiSppPacket& packet);
    DualConnectDevice parse_dual_connect_device(const HuaweiSppPacket& packet);
    void populate_equalizer_info(EqualizerInfo& info, const HuaweiSppPacket& packet);
    AncStatus parse_anc_status(const HuaweiSppPacket& packet);
};