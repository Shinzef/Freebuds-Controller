#pragma once

#include <vector>
#include <string>
#include <cstdint>

// This is the "contract" or abstract base class that any platform's
// Bluetooth SPP client must implement.
// Our platform-independent `core` logic will only ever interact with
// a pointer or reference to this interface, never with a concrete
// implementation like `BluetoothSPPClient` directly.
class IBluetoothSPPClient {
public:
    // A virtual destructor is essential for any class intended to be a base class.
    virtual ~IBluetoothSPPClient() = default;

    // Pure virtual functions that MUST be implemented by any concrete class.
    virtual bool connect(const std::string& address, int port) = 0;
    virtual void disconnect() = 0;
    virtual bool send(const std::vector<uint8_t>& data) = 0;
    virtual std::vector<std::vector<uint8_t>> receive_all() = 0;
    virtual bool is_connected() const = 0;
};