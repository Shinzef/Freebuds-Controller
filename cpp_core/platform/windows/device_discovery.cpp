#include "device_discovery.h"
#include <iostream>
#include <sstream>
#include <iomanip>

// C++/WinRT Headers
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Bluetooth.h>

// Use the C++/WinRT namespace
using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Devices::Enumeration;
using namespace Windows::Devices::Bluetooth;

// Helper to format the 64-bit Bluetooth address into a human-readable string
std::string format_bluetooth_address(uint64_t address) {
    std::stringstream ss;
    ss << std::hex << std::uppercase << std::setfill('0');
    ss << std::setw(2) << ((address >> 40) & 0xFF) << ":"
       << std::setw(2) << ((address >> 32) & 0xFF) << ":"
       << std::setw(2) << ((address >> 24) & 0xFF) << ":"
       << std::setw(2) << ((address >> 16) & 0xFF) << ":"
       << std::setw(2) << ((address >> 8) & 0xFF) << ":"
       << std::setw(2) << (address & 0xFF);
    return ss.str();
}


std::optional<std::string> find_first_device_by_name(const std::wstring& target_name) {
    // Initialize the Windows Runtime for this thread
    init_apartment();

    try {
        // Get an AQS (Advanced Query Syntax) string for all paired Bluetooth devices.
        // This is the equivalent of the Python code's GetDeviceSelectorFromPairingState(true)
        hstring aqs_selector = BluetoothDevice::GetDeviceSelectorFromPairingState(true);

        // Find all devices matching the selector.
        // The .get() call waits for the async operation to complete.
        DeviceInformationCollection devices = DeviceInformation::FindAllAsync(aqs_selector).get();

        if (devices.Size() == 0) {
            std::wcerr << L"No paired Bluetooth devices found." << std::endl;
            return std::nullopt;
        }

        // Iterate over all found devices
        for (DeviceInformation dev_info : devices) {
            if (dev_info.Name() == target_name) {
                // We found a device with the matching name! Now, get its address.
                // The address is not in DeviceInformation, we need the BluetoothDevice object.
                BluetoothDevice bt_device = BluetoothDevice::FromIdAsync(dev_info.Id()).get();
                if (bt_device) {
                    uint64_t address = bt_device.BluetoothAddress();
                    return format_bluetooth_address(address);
                }
            }
        }
    }
    catch (const hresult_error& ex) {
        std::wcerr << L"WinRT error occurred: " << ex.message().c_str() << std::endl;
    }

    // If we get here, no device was found
    return std::nullopt;
}