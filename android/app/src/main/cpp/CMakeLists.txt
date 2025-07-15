# The minimum version of CMake required.
cmake_minimum_required(VERSION 3.22.1)

# Set the project name.
project(OpenFreebudsCore CXX)

# Define a variable that points to our shared C++ source directory.
# From android/app/src/main/cpp/ we need to go up 5 levels to reach the project root
set(SHARED_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../cpp_core)

# Debug: Print the resolved path to verify it's correct
message(STATUS "SHARED_CPP_DIR resolved to: ${SHARED_CPP_DIR}")

# We MUST define the library with add_library() FIRST.
add_library(
        OpenFreebudsCore
        SHARED

        # Android-specific bridge file
        jni_bridge.cpp

        # All the shared source files from our new location
        ${SHARED_CPP_DIR}/core/device.cpp
        ${SHARED_CPP_DIR}/core/command_writer.cpp
        ${SHARED_CPP_DIR}/protocol/crc16.cpp
        ${SHARED_CPP_DIR}/protocol/huawei_packet.cpp
        ${SHARED_CPP_DIR}/platform/android/bluetooth_spp_client_android.cpp
)

# NOW that the "OpenFreebudsCore" target exists, we can modify it.
target_include_directories(OpenFreebudsCore PUBLIC
        ${SHARED_CPP_DIR}
)

# And now we can link libraries to it.
find_library(log-lib log)
target_link_libraries(OpenFreebudsCore PRIVATE ${log-lib})