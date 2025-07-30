// cpp_core/core/command_writer.h

#pragma once
#include "platform/bluetooth_interface.h"
#include "protocol/huawei_packet.h"
#include "core/types.h"
#include "core/thread_safe_queue.h"
#include <string>
#include <vector>
#include <map>
#include <thread>
#include <functional>
#include <atomic>

class CommandWriter {
 public:
  CommandWriter(IBluetoothSPPClient& client);
  ~CommandWriter();

  // --- Sound Settings ---
  void set_anc_mode(AncMode mode);
  void set_anc_level(AncLevel level);
  void set_wear_detection(bool enable);
  void set_low_latency(bool enable);
  void set_sound_quality_preference(bool prioritize_quality);
  void create_fake_preset(FakePreset preset, uint8_t new_id);

  // --- Gesture Methods ---
  void set_double_tap_action(EarSide side, GestureAction action);
  void set_triple_tap_action(EarSide side, GestureAction action);
  void set_swipe_action(GestureAction action);
  void set_long_tap_action(EarSide side, GestureAction action);
  void set_long_tap_anc_cycle(EarSide side, AncCycleMode cycle_mode);
  void set_incall_double_tap_action(GestureAction action);

  // --- Equalizer Methods ---
  void set_equalizer_preset(uint8_t preset_id);
  void create_or_update_custom_equalizer(const CustomEqPreset& preset);
  void delete_custom_equalizer(const CustomEqPreset& preset);

  // --- Dual-Connect Methods ---
  void set_dual_connect_enabled(bool enable);
  void set_dual_connect_preferred(const std::string& mac_address);
  void dual_connect_action(const std::string& mac_address, uint8_t action_code);

 private:
  void send_and_log(const HuaweiSppPacket& request, const std::string& description);

  void process_queue();
  ThreadSafeQueue<std::function<void()>> m_command_queue;
  std::thread m_worker_thread;
  std::atomic<bool> m_running;
  IBluetoothSPPClient& m_client;
};