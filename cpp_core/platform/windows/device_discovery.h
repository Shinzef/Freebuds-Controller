#pragma once
#include <string>
#include <optional>

// This function will search for a paired Bluetooth device by its name.
// It returns the MAC address string if found, otherwise std::nullopt.
std::optional<std::string> find_first_device_by_name(const std::wstring& target_name);