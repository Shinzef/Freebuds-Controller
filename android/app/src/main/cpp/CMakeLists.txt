cmake_minimum_required(VERSION 3.22.1) # Use the version Android Studio provides
project(OpenFreebudsCore CXX)

# --- Define Common/Portable Source Files ---
# These files are used on ALL platforms.
set(COMMON_SOURCES
        core/device.cpp
        core/command_writer.cpp
        protocol/crc16.cpp
        protocol/huawei_packet.cpp
)

# --- Define Platform-Specific Source Files ---
if(WIN32 AND NOT ANDROID) # Building for Windows Desktop
    message(STATUS "Configuring for Windows Desktop")
    set(PLATFORM_SOURCES
            platform/windows/bluetooth_spp_client.cpp
            platform/windows/device_discovery.cpp
    )
elseif(ANDROID) # Building for Android
    message(STATUS "Configuring for Android")
    set(PLATFORM_SOURCES
            platform/android/bluetooth_spp_client_android.cpp
            jni_bridge.cpp # JNI is specific to our Android implementation
    )
else()
    message(FATAL_ERROR "Unsupported platform!")
endif()

# --- Create the Shared Library ---
# We combine the common sources with the platform-specific sources.
add_library(
        OpenFreebudsCore
        SHARED
        ${COMMON_SOURCES}
        ${PLATFORM_SOURCES}
)

# --- Set Include Directories ---
target_include_directories(OpenFreebudsCore PUBLIC
        . # The cpp directory is the root, so we can find core/, protocol/, etc.
)

# --- Link Platform-Specific Libraries ---
if(WIN32 AND NOT ANDROID)
    target_link_libraries(OpenFreebudsCore PRIVATE ws2_32 bthprops)
elseif(ANDROID)
    # Find and link the standard Android logging library
    find_library(log-lib log)
    target_link_libraries(OpenFreebudsCore PRIVATE ${log-lib})
endif()