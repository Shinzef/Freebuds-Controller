#include "huawei_packet.h"
#include "crc16.h"
#include <iostream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

HuaweiSppPacket::HuaweiSppPacket(uint16_t cmd_id) : command_id(cmd_id) {}

HuaweiSppPacket HuaweiSppPacket::create_read_request(std::array<uint8_t, 2> cmd, const std::vector<uint8_t>& params_to_read) {
    HuaweiSppPacket packet(bytes_to_u16(cmd[0], cmd[1]));
    for (uint8_t param_id : params_to_read) {
        packet.parameters[param_id] = {}; // Empty value for a read request
    }
    return packet;
}

std::vector<uint8_t> HuaweiSppPacket::to_bytes() const {
    std::vector<uint8_t> body;
    body.push_back(command_id >> 8);
    body.push_back(command_id & 0xFF);

    for (const auto& pair : parameters) {
        body.push_back(pair.first);
        body.push_back(static_cast<uint8_t>(pair.second.size()));
        body.insert(body.end(), pair.second.begin(), pair.second.end());
    }

    std::vector<uint8_t> packet_data;
    packet_data.push_back(0x5A);
    uint16_t body_len_with_header = body.size() + 1;
    packet_data.push_back(body_len_with_header >> 8);
    packet_data.push_back(body_len_with_header & 0xFF);
    packet_data.push_back(0x00);
    packet_data.insert(packet_data.end(), body.begin(), body.end());

    uint16_t crc = crc16_xmodem(packet_data.data(), packet_data.size());
    packet_data.push_back(crc >> 8);
    packet_data.push_back(crc & 0xFF);

    return packet_data;
}

std::optional<HuaweiSppPacket> HuaweiSppPacket::from_bytes(const std::vector<uint8_t>& data) {
    if (data.size() < 6 || data[0] != 0x5A || data[3] != 0x00) {
        return std::nullopt;
    }

    uint16_t calculated_crc = crc16_xmodem(data.data(), data.size() - 2);
    uint16_t received_crc = bytes_to_u16(data[data.size() - 2], data[data.size() - 1]);

    if (calculated_crc != received_crc) {
        // You might want to log this error
        return std::nullopt;
    }

    HuaweiSppPacket packet(bytes_to_u16(data[4], data[5]));
    size_t pos = 6;
    while (pos < data.size() - 2) {
        uint8_t p_type = data[pos++];
        uint8_t p_len = data[pos++];
        if (pos + p_len > data.size() - 2) {
            return std::nullopt; // Malformed packet
        }
        packet.parameters[p_type] = std::vector<uint8_t>(data.begin() + pos, data.begin() + pos + p_len);
        pos += p_len;
    }

    return packet;
}

std::optional<std::vector<uint8_t>> HuaweiSppPacket::get_param(uint8_t key) const {
    auto it = parameters.find(key);
    if (it != parameters.end()) {
        return it->second;
    }
    return std::nullopt;
}

std::string HuaweiSppPacket::to_string() const {
    std::stringstream ss;
    ss << "Command: 0x" << std::hex << std::setfill('0') << std::setw(4) << command_id << std::dec << "\n";
    for(const auto& pair : parameters) {
        ss << "  Param " << (int)pair.first << " (len " << pair.second.size() << "): ";
        for(uint8_t byte : pair.second) {
            ss << std::hex << std::setfill('0') << std::setw(2) << (int)byte << " ";
        }
        ss << std::dec << "\n";
    }
    return ss.str();
}

HuaweiSppPacket HuaweiSppPacket::create_write_request(std::array<uint8_t, 2> cmd, uint8_t param_key, const std::vector<uint8_t>& param_value) {
    HuaweiSppPacket packet(bytes_to_u16(cmd[0], cmd[1]));
    packet.parameters[param_key] = param_value;
    return packet;
}