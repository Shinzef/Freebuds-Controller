#pragma once
#include "platform/bluetooth_interface.h"
#include "protocol/huawei_packet.h"
#include "core/types.h"
#include <string>
#include <vector>
#include <map>

class CommandWriter {
public:
    CommandWriter(IBluetoothSPPClient& client);

    // --- Sound Settings ---
    bool set_anc_mode(AncMode mode);
    bool set_anc_level(AncLevel level);
    bool set_wear_detection(bool enable);
    bool set_low_latency(bool enable);
    bool set_sound_quality_preference(bool prioritize_quality);
    bool create_fake_preset(FakePreset preset, uint8_t new_id);

    // --- Gesture Methods ---
    bool set_double_tap_action(EarSide side, GestureAction action);
    bool set_triple_tap_action(EarSide side, GestureAction action);
    bool set_swipe_action(GestureAction action);
    bool set_long_tap_action(EarSide side, GestureAction action);
    bool set_long_tap_anc_cycle(EarSide side, AncCycleMode cycle_mode);
    bool set_incall_double_tap_action(GestureAction action);

    // --- Equalizer Methods ---
    bool set_equalizer_preset(uint8_t preset_id);
    bool create_or_update_custom_equalizer(const CustomEqPreset& preset);
    bool delete_custom_equalizer(uint8_t preset_id);

    // --- Dual-Connect Methods ---
    bool set_dual_connect_enabled(bool enable);
    bool set_dual_connect_preferred(const std::string& mac_address);
    bool dual_connect_action(const std::string& mac_address, uint8_t action_code); // 1=connect, 2=disconnect, 3=unpair

private:
    IBluetoothSPPClient& m_client;
    void send_and_log(const HuaweiSppPacket& request, const std::string& description);
};