#include "platform/android/bluetooth_spp_client_android.h"
#include <stdexcept>
#include <iostream>
#include <android/log.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "BT_CLIENT", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "BT_CLIENT", __VA_ARGS__)

JNIEnv* BluetoothSppClientAndroid::get_env() {
    JNIEnv* env;
    int status = m_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        status = m_vm->AttachCurrentThread(&env, nullptr);
        if (status != JNI_OK) {
            throw std::runtime_error("Failed to attach current thread to JVM");
        }
    } else if (status != JNI_OK) {
        throw std::runtime_error("Failed to get JNI environment");
    }
    return env;
}

BluetoothSppClientAndroid::BluetoothSppClientAndroid(JavaVM* vm, jobject bluetoothManager)
        : m_vm(vm) {

    JNIEnv* env = get_env();
    m_bluetoothManagerJavaObject = env->NewGlobalRef(bluetoothManager);
    if (m_bluetoothManagerJavaObject == nullptr) {
        throw std::runtime_error("Failed to create global reference for BluetoothManager");
    }

    jclass managerClass = env->GetObjectClass(m_bluetoothManagerJavaObject);
    if (managerClass == nullptr) {
        throw std::runtime_error("Failed to find BluetoothManager class");
    }

    m_connectMethodId = env->GetMethodID(managerClass, "connect", "(Ljava/lang/String;)Z");
    m_disconnectMethodId = env->GetMethodID(managerClass, "disconnect", "()V");
    m_sendMethodId = env->GetMethodID(managerClass, "send", "([B)Z");
    m_receiveMethodId = env->GetMethodID(managerClass, "receive", "(J)[B");
    m_isConnectedMethodId = env->GetMethodID(managerClass, "isConnected", "()Z");

    env->DeleteLocalRef(managerClass);

    if (!m_connectMethodId || !m_disconnectMethodId || !m_sendMethodId || !m_receiveMethodId || !m_isConnectedMethodId) {
        throw std::runtime_error("Failed to find one or more BluetoothManager methods");
    }

    LOGI("BluetoothSppClientAndroid initialized successfully");
}

BluetoothSppClientAndroid::~BluetoothSppClientAndroid() {
    JNIEnv* env = get_env();
    if (m_bluetoothManagerJavaObject) {
        env->DeleteGlobalRef(m_bluetoothManagerJavaObject);
    }
    LOGI("BluetoothSppClientAndroid destroyed");
}

bool BluetoothSppClientAndroid::connect(const std::string& address, int port) {
    JNIEnv* env = get_env();
    jstring javaAddress = env->NewStringUTF(address.c_str());
    bool result = env->CallBooleanMethod(m_bluetoothManagerJavaObject, m_connectMethodId, javaAddress);
    env->DeleteLocalRef(javaAddress);

    LOGI("Connect result: %d", result);
    return result;
}

void BluetoothSppClientAndroid::disconnect() {
    JNIEnv* env = get_env();
    env->CallVoidMethod(m_bluetoothManagerJavaObject, m_disconnectMethodId);
    LOGI("Disconnect called");
}

bool BluetoothSppClientAndroid::send(const std::vector<uint8_t>& data) {
    JNIEnv* env = get_env();
    jbyteArray javaBytes = env->NewByteArray(data.size());
    env->SetByteArrayRegion(javaBytes, 0, data.size(), reinterpret_cast<const jbyte*>(data.data()));

    bool result = env->CallBooleanMethod(m_bluetoothManagerJavaObject, m_sendMethodId, javaBytes);
    env->DeleteLocalRef(javaBytes);

    LOGI("Send result: %d", result);
    return result;
}

std::vector<std::vector<uint8_t>> BluetoothSppClientAndroid::receive_all() {
    JNIEnv* env = get_env();
    std::vector<std::vector<uint8_t>> all_packets;

    while(true) {
        jbyteArray javaBytes = (jbyteArray)env->CallObjectMethod(m_bluetoothManagerJavaObject, m_receiveMethodId, (jlong)500);

        if (javaBytes == nullptr) {
            break;
        }

        jsize len = env->GetArrayLength(javaBytes);
        std::vector<uint8_t> cppBytes(len);
        env->GetByteArrayRegion(javaBytes, 0, len, reinterpret_cast<jbyte*>(cppBytes.data()));

        all_packets.push_back(cppBytes);
        env->DeleteLocalRef(javaBytes);
    }

    LOGI("Received %zu packets", all_packets.size());
    return all_packets;
}

bool BluetoothSppClientAndroid::is_connected() const {
    JNIEnv* env = const_cast<BluetoothSppClientAndroid*>(this)->get_env();
    bool result = env->CallBooleanMethod(m_bluetoothManagerJavaObject, m_isConnectedMethodId);
    return result;
}