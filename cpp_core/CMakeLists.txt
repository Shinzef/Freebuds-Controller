# In cpp_core/CMakeLists.txt

cmake_minimum_required(VERSION 3.10)
project(OpenFreebudsCore CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Check if target already exists
if(NOT TARGET OpenFreebudsCore)
    # --- 1. Define all the source files for the library ---
    set(SOURCE_FILES
            # Shared core logic
            core/device.cpp
            core/command_writer.cpp

            # Shared protocol logic
            protocol/crc16.cpp
            protocol/huawei_packet.cpp

            # Platform-specific implementation for Windows
            platform/windows/bluetooth_spp_client.cpp
            platform/windows/device_discovery.cpp
    )

    # --- 2. Create the shared library (.dll) from the source files ---
    add_library(OpenFreebudsCore SHARED ${SOURCE_FILES})

    # --- 3. Add this directory to the include path ---
    target_include_directories(OpenFreebudsCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

    # --- 4. Link against the required Windows libraries ---
    if(WIN32)
        target_link_libraries(OpenFreebudsCore PRIVATE ws2_32 bthprops)
    endif()

    # --- 5. Set proper output directories for all library components ---
    set_target_properties(OpenFreebudsCore PROPERTIES
            # Where the .lib file (import library) goes
            ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/libs/$<CONFIG>"
            ARCHIVE_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/libs/Debug"
            ARCHIVE_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/libs/Release"

            # Where the .dll file goes
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/libs/$<CONFIG>"
            RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/libs/Debug"
            RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/libs/Release"

            # Additional library output directory
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/libs/$<CONFIG>"
            LIBRARY_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/libs/Debug"
            LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/libs/Release"
    )

    # --- 6. Ensure symbols are exported for Windows DLL ---
    set_target_properties(OpenFreebudsCore PROPERTIES
            WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()