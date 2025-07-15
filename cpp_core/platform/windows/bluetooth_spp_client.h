#pragma once
#include "platform/bluetooth_interface.h"

// --- Windows Headers - Order is important! ---
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
#include <ws2bth.h>
#include <windows.h>
#include <BluetoothAPIs.h>

// Link against required libraries
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "Bthprops.lib")

// Inherit publicly from the interface.
class BluetoothSPPClient : public IBluetoothSPPClient {
public:
    BluetoothSPPClient();
    ~BluetoothSPPClient();

    bool connect(const std::string& address, int port) override;
    void disconnect() override;
    bool send(const std::vector<uint8_t>& data) override;
    std::vector<std::vector<uint8_t>> receive_all() override;
    bool is_connected() const override;

private:
    bool refresh_device_record(const BTH_ADDR& btAddr);

    SOCKET sock = INVALID_SOCKET;
    bool connected = false;
};