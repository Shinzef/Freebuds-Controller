#pragma once
#include <vector>
#include <map>
#include <string>
#include <cstdint>
#include <array>
#include <optional>

// --- Helper Function ---
// Move this function here and mark it as inline
inline uint16_t bytes_to_u16(uint8_t b1, uint8_t b2) {
    return (static_cast<uint16_t>(b1) << 8) | b2;
}

class HuaweiSppPacket {
public:
    uint16_t command_id;
    std::map<uint8_t, std::vector<uint8_t>> parameters;

    HuaweiSppPacket(uint16_t cmd_id);

    // Factory methods for creating common request packets
    static HuaweiSppPacket create_read_request(std::array<uint8_t, 2> cmd, const std::vector<uint8_t>& params_to_read);

    // Methods for serialization and parsing
    std::vector<uint8_t> to_bytes() const;
    static std::optional<HuaweiSppPacket> from_bytes(const std::vector<uint8_t>& data);

    // Helper to get a parameter
    std::optional<std::vector<uint8_t>> get_param(uint8_t key) const;
    std::string to_string() const;

    // Methods to write
    static HuaweiSppPacket create_write_request(std::array<uint8_t, 2> cmd, uint8_t param_key, const std::vector<uint8_t>& param_value);
};