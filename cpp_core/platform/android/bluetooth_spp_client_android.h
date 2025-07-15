#pragma once
#include "platform/bluetooth_interface.h"
#include <jni.h>

class BluetoothSppClientAndroid : public IBluetoothSPPClient {
public:
    // We now take the JavaVM pointer as well
    explicit BluetoothSppClientAndroid(JavaVM* vm, jobject bluetoothManager);
    ~BluetoothSppClientAndroid() override;

    bool connect(const std::string& address, int port) override;
    void disconnect() override;
    bool send(const std::vector<uint8_t>& data) override;
    std::vector<std::vector<uint8_t>> receive_all() override;
    bool is_connected() const override;

private:
    JavaVM* m_vm; // Pointer to the Java Virtual Machine
    jobject m_bluetoothManagerJavaObject; // Global reference to the Kotlin object

    // Cached method IDs
    jmethodID m_connectMethodId = nullptr;
    jmethodID m_disconnectMethodId = nullptr;
    jmethodID m_sendMethodId = nullptr;
    jmethodID m_receiveMethodId = nullptr;
    jmethodID m_isConnectedMethodId = nullptr;  // <-- This was missing!

    // Helper to get a valid JNIEnv* for the current thread
    JNIEnv* get_env();
};