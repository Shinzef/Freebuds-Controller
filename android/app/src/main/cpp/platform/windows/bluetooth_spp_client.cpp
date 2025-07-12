#include "bluetooth_spp_client.h"
#include <iostream>
#include <vector>

// str_to_addr function remains the same...
int str_to_addr(const std::string& strAddr, BTH_ADDR& btAddr) {
    if (strAddr.length() != 17) return 1;
    unsigned int addr[6];
    int res = sscanf_s(strAddr.c_str(), "%02x:%02x:%02x:%02x:%02x:%02x",
        &addr[0], &addr[1], &addr[2], &addr[3], &addr[4], &addr[5]);
    if (res != 6) return 1;
    btAddr = 0;
    for (int i = 0; i < 6; ++i) {
        btAddr = (btAddr << 8) + addr[i];
    }
    return 0;
}

bool BluetoothSPPClient::refresh_device_record(const BTH_ADDR& btAddr) {
    // Use the actual Windows Bluetooth API
    BLUETOOTH_DEVICE_SEARCH_PARAMS searchParams = { 0 };
    searchParams.dwSize = sizeof(BLUETOOTH_DEVICE_SEARCH_PARAMS);
    searchParams.fReturnAuthenticated = TRUE;
    searchParams.fReturnRemembered = TRUE;
    searchParams.fReturnConnected = TRUE;
    searchParams.fReturnUnknown = FALSE;
    searchParams.fIssueInquiry = FALSE;
    searchParams.cTimeoutMultiplier = 0;

    BLUETOOTH_DEVICE_INFO deviceInfo = { 0 };
    deviceInfo.dwSize = sizeof(BLUETOOTH_DEVICE_INFO);

    HBLUETOOTH_DEVICE_FIND hFind = BluetoothFindFirstDevice(&searchParams, &deviceInfo);
    if (hFind) {
        do {
            if (deviceInfo.Address.ullLong == btAddr) {
                std::cout << "  Found device record. Forcing an update..." << std::endl;
                DWORD result = BluetoothUpdateDeviceRecord(&deviceInfo);
                BluetoothFindDeviceClose(hFind);
                if (result == ERROR_SUCCESS) {
                    std::cout << "  Device record updated successfully." << std::endl;
                    Sleep(500);
                    return true;
                } else {
                    std::cerr << "  BluetoothUpdateDeviceRecord failed with error: " << result << std::endl;
                }
                break;
            }
        } while (BluetoothFindNextDevice(hFind, &deviceInfo));

        BluetoothFindDeviceClose(hFind);
    } else {
        std::cerr << "  Could not find any Bluetooth devices." << std::endl;
    }
    return false;
}

BluetoothSPPClient::BluetoothSPPClient() {
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        throw std::runtime_error("WSAStartup failed");
    }
}

BluetoothSPPClient::~BluetoothSPPClient() {
    disconnect();
    WSACleanup();
}

bool BluetoothSPPClient::connect(const std::string& address, int port) {
    if (connected) disconnect();

    SOCKADDR_BTH bt_addr_sock = {0};
    bt_addr_sock.addressFamily = AF_BTH;
    bt_addr_sock.port = port;

    BTH_ADDR bth_addr_native = 0;
    if (str_to_addr(address, bth_addr_native) != 0) {
        std::cerr << "Invalid Bluetooth address format." << std::endl;
        return false;
    }
    bt_addr_sock.btAddr = bth_addr_native;

    std::cout << "  Refreshing device services cache..." << std::endl;
    if (!refresh_device_record(bth_addr_native)) {
        std::cout << "  Could not refresh device record, but will attempt to connect anyway." << std::endl;
    }

    sock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (sock == INVALID_SOCKET) {
        std::cerr << "Socket creation failed: " << WSAGetLastError() << std::endl;
        return false;
    }

    DWORD timeout = 1500;
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout)) == SOCKET_ERROR) {
        std::cerr << "setsockopt for SO_RCVTIMEO failed with error: " << WSAGetLastError() << std::endl;
        closesocket(sock);
        return false;
    }

    if (::connect(sock, (SOCKADDR*)&bt_addr_sock, sizeof(bt_addr_sock)) == SOCKET_ERROR) {
        std::cerr << "Connect failed: " << WSAGetLastError() << std::endl;
        closesocket(sock);
        sock = INVALID_SOCKET;
        return false;
    }

    connected = true;
    return true;
}

void BluetoothSPPClient::disconnect() {
    if (sock != INVALID_SOCKET) {
        closesocket(sock);
        sock = INVALID_SOCKET;
    }
    connected = false;
}

bool BluetoothSPPClient::send(const std::vector<uint8_t>& data) {
    if (!connected) return false;
    int bytes_sent = ::send(sock, (const char*)data.data(), (int)data.size(), 0);
    return bytes_sent == data.size();
}

std::vector<std::vector<uint8_t>> BluetoothSPPClient::receive_all() {
    if (!connected) return {};

    std::vector<std::vector<uint8_t>> all_packets;

    while(true) {
        std::vector<uint8_t> header(4);
        int bytes_read = recv(sock, (char*)header.data(), 4, 0);

        if (bytes_read == SOCKET_ERROR) {
            if (WSAGetLastError() == WSAETIMEDOUT) {
                // This is expected, means no more data
                break;
            }
            std::cerr << "recv failed with error: " << WSAGetLastError() << std::endl;
            break;
        }

        if (bytes_read == 0) {
            std::cerr << "Connection closed by peer." << std::endl;
            disconnect();
            break;
        }

        if (bytes_read != 4 || header[0] != 0x5A || header[3] != 0x00) {
            std::cerr << "Invalid packet header received." << std::endl;
            continue; // Try to recover by looking for the next packet
        }

        uint16_t body_len_with_header = (static_cast<uint16_t>(header[1]) << 8) | header[2];
        uint16_t remaining_len = (body_len_with_header - 1) + 2; // -1 for already-read header part, +2 for CRC

        std::vector<uint8_t> full_packet = header;
        full_packet.resize(4 + remaining_len);

        bytes_read = recv(sock, (char*)full_packet.data() + 4, remaining_len, MSG_WAITALL);

        if (bytes_read == remaining_len) {
            all_packets.push_back(full_packet);
        } else {
            std::cerr << "Failed to read full packet body." << std::endl;
            // Don't break, maybe another packet will come
        }
    }

    return all_packets;
}

bool BluetoothSPPClient::is_connected() const {
    return connected;
}