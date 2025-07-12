package com.example.freebuds_flutter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "freebuds/bluetooth"
    private lateinit var bluetoothManager: BluetoothManager
    private var devicePointer: Long = 0
    private var useNativeLibrary = false

    companion object {
        init {
            try {
                // This loads the entire C++ library, making all native functions available.
                System.loadLibrary("OpenFreebudsCore")
                println("✅ OpenFreebudsCore library loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                println("❌ Failed to load OpenFreebudsCore library: ${e.message}")
            }
        }
    }

    // --- JNI Function Declarations ---
    // These now map directly to the C++ Device object's methods via the bridge
    private external fun createDevice(btManager: BluetoothManager): Long
    private external fun freeDevice(devicePtr: Long)
    private external fun nativeConnect(devicePtr: Long, address: String): Boolean
    private external fun nativeDisconnect(devicePtr: Long)
    private external fun nativeIsConnected(devicePtr: Long): Boolean
    private external fun getDeviceInfoFromNative(devicePtr: Long): String?
    private external fun getBatteryFromNative(devicePtr: Long): Map<String, Int>?
    private external fun setAncModeNative(devicePtr: Long, mode: Int): Boolean
    private external fun nativeGetWearDetectionStatus(devicePtr: Long): Boolean
    private external fun nativeSetWearDetection(devicePtr: Long, enable: Boolean): Boolean
    private external fun nativeGetLowLatencyStatus(devicePtr: Long): Boolean
    private external fun nativeSetLowLatency(devicePtr: Long, enable: Boolean): Boolean
    private external fun nativeGetSoundQuality(devicePtr: Long): Int
    private external fun nativeSetSoundQuality(devicePtr: Long, preference: Int): Boolean
    private external fun nativeGetAncStatus(devicePtr: Long): Map<String, Int>?
    private external fun nativeSetAncLevel(devicePtr: Long, level: Int): Boolean
    private external fun nativeGetGestureSettings(devicePtr: Long): Map<String, Int>?
    private external fun nativeSetDoubleTapAction(devicePtr: Long, side: Int, action: Int): Boolean
    private external fun nativeSetTripleTapAction(devicePtr: Long, side: Int, action: Int): Boolean
    private external fun nativeSetLongTapAction(devicePtr: Long, side: Int, action: Int): Boolean
    private external fun nativeSetSwipeAction(devicePtr: Long, action: Int): Boolean
    private external fun nativeGetEqualizerInfo(devicePtr: Long): Map<String, Any>?
    private external fun nativeSetEqualizerPreset(devicePtr: Long, presetId: Int): Boolean
    private external fun nativeCreateOrUpdateCustomEqualizer(devicePtr: Long, id: Int, name: String, values: IntArray): Boolean
    private external fun nativeDeleteCustomEqualizer(devicePtr: Long, presetId: Int): Boolean

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Initialize the Kotlin BluetoothManager which handles the low-level connection.
        bluetoothManager = BluetoothManager(this)
        println("✅ BluetoothManager initialized")

        // 2. Initialize the C++ Core Library.
        // This creates the C++ 'Device' object and passes it our Kotlin BluetoothManager.
        // From now on, the C++ side can use the Kotlin manager to send/receive data.
        try {
            devicePointer = createDevice(bluetoothManager)
            if (devicePointer != 0L) {
                useNativeLibrary = true
                println("✅ Native C++ Device object created successfully. Pointer: $devicePointer")
            } else {
                println("❌ Native createDevice returned a null pointer.")
            }
        } catch (e: UnsatisfiedLinkError) {
            println("❌ Native code not available, cannot create device: ${e.message}")
            useNativeLibrary = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Check if native library is available for methods that require it.
            if (!useNativeLibrary && call.method !in listOf("connectDevice", "disconnectDevice", "isConnected")) {
                result.error("NATIVE_UNAVAILABLE", "The C++ core library is not available.", null)
                return@setMethodCallHandler
            }

            // Route calls from Flutter to the C++ Backend
            when (call.method) {
                "connectDevice" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "HUAWEI FreeBuds 6i"
                    connectToDevice(deviceName, result)
                }
                "disconnectDevice" -> disconnectDevice(result)
                "getDeviceInfo" -> getDeviceInfo(result)
                "isConnected" -> result.success(bluetoothManager.isConnected())
                "getBatteryInfo" -> getBatteryInfo(result)
                "setAncMode" -> setProperty(call.argument<Int>("mode"), result) { arg -> setAncModeNative(devicePointer, arg) }
                "getWearDetection" -> getProperty(result) { nativeGetWearDetectionStatus(devicePointer) }
                "setWearDetection" -> setProperty(call.argument<Boolean>("enable"), result) { arg -> nativeSetWearDetection(devicePointer, arg) }

                "getLowLatency" -> getProperty(result) { nativeGetLowLatencyStatus(devicePointer) }
                "setLowLatency" -> setProperty(call.argument<Boolean>("enable"), result) { arg -> nativeSetLowLatency(devicePointer, arg) }

                "getSoundQuality" -> getProperty(result) { nativeGetSoundQuality(devicePointer) }
                "setSoundQuality" -> setProperty(call.argument<Int>("preference"), result) { arg -> nativeSetSoundQuality(devicePointer, arg) }

                "getAncStatus" -> getProperty(result) { nativeGetAncStatus(devicePointer) }
                "setAncLevel" -> setProperty(call.argument<Int>("level"), result) { arg -> nativeSetAncLevel(devicePointer, arg) }

                "getGestureSettings" -> getProperty(result) { nativeGetGestureSettings(devicePointer) }
                "setDoubleTapAction" -> {
                    val side = call.argument<Int>("side")
                    val action = call.argument<Int>("action")
                    setProperty(Pair(side, action), result) { args -> nativeSetDoubleTapAction(devicePointer, args.first!!, args.second!!) }
                }
                "setTripleTapAction" -> {
                    val side = call.argument<Int>("side")
                    val action = call.argument<Int>("action")
                    setProperty(Pair(side, action), result) { args -> nativeSetTripleTapAction(devicePointer, args.first!!, args.second!!) }
                }
                "setLongTapAction" -> {
                    val side = call.argument<Int>("side")
                    val action = call.argument<Int>("action")
                    setProperty(Pair(side, action), result) { args -> nativeSetLongTapAction(devicePointer, args.first!!, args.second!!) }
                }
                "setSwipeAction" -> {
                    val action = call.argument<Int>("action")
                    setProperty(action, result) { arg -> nativeSetSwipeAction(devicePointer, arg) }
                }

                "getEqualizerInfo" -> getProperty(result) { nativeGetEqualizerInfo(devicePointer) }
                "setEqualizerPreset" -> setProperty(call.argument<Int>("presetId"), result) { arg -> nativeSetEqualizerPreset(devicePointer, arg) }

                "createOrUpdateCustomEq" -> {
                    val id = call.argument<Int>("id")
                    val name = call.argument<String>("name")
                    val values = call.argument<ArrayList<Int>>("values")?.toIntArray()
                    if (id == null || name == null || values == null) {
                        result.error("INVALID_ARGS", "Missing arguments for creating/updating EQ.", null)
                    } else {
                        setProperty(Triple(id, name, values), result) { args -> nativeCreateOrUpdateCustomEqualizer(devicePointer, args.first, args.second, args.third) }
                    }
                }
                "deleteCustomEq" -> setProperty(call.argument<Int>("presetId"), result) { arg -> nativeDeleteCustomEqualizer(devicePointer, arg) }

                "scanForDevices" -> scanForDevices(result)
                else -> result.notImplemented()
            }
        }
    }

    // --- Method Implementations ---

    private fun connectToDevice(deviceName: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            // The C++ layer now initiates the connection
            val success = nativeConnect(devicePointer, deviceName)
            withContext(Dispatchers.Main) {
                if (success) {
                    result.success(true)
                } else {
                    result.error("CONNECTION_ERROR", "Native connection failed for device: $deviceName", null)
                }
            }
        }
    }
    private fun disconnectDevice(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            nativeDisconnect(devicePointer)
            withContext(Dispatchers.Main) {
                result.success(true)
            }
        }
    }

    private fun guardNotConnected(result: MethodChannel.Result): Boolean {
        if (!nativeIsConnected(devicePointer)) {
            result.error("NOT_CONNECTED", "Device is not connected.", null)
            return true
        }
        return false
    }

    private fun getDeviceInfo(result: MethodChannel.Result) {
        if (guardNotConnected(result)) return
        CoroutineScope(Dispatchers.IO).launch {
            val info = getDeviceInfoFromNative(devicePointer)
            withContext(Dispatchers.Main) {
                result.success(info)
            }
        }
    }

    private fun getBatteryInfo(result: MethodChannel.Result) {
        if (guardNotConnected(result)) return
        CoroutineScope(Dispatchers.IO).launch {
            val batteryData = getBatteryFromNative(devicePointer)
            withContext(Dispatchers.Main) {
                result.success(batteryData)
            }
        }
    }

    private fun setAncMode(mode: Int, result: MethodChannel.Result) {
        if (guardNotConnected(result)) return
        CoroutineScope(Dispatchers.IO).launch {
            val success = setAncModeNative(devicePointer, mode)
            withContext(Dispatchers.Main) {
                result.success(success)
            }
        }
    }

    private fun scanForDevices(result: MethodChannel.Result) {
        try {
            val devices = listOf("HUAWEI FreeBuds 6i", "HUAWEI FreeBuds Pro")
            result.success(devices)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", e.message, null)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (useNativeLibrary && devicePointer != 0L) {
            // Ensure we disconnect and free the C++ object to prevent memory leaks
            nativeDisconnect(devicePointer)
            freeDevice(devicePointer)
            println("✅ Native C++ Device object freed.")
            devicePointer = 0L
        }
    }

    private fun <T> getProperty(result: MethodChannel.Result, getter: () -> T) {
        if (guardNotConnected(result)) return
        CoroutineScope(Dispatchers.IO).launch {
            val value = getter()
            withContext(Dispatchers.Main) {
                result.success(value)
            }
        }
    }

    private fun <T> setProperty(arg: T?, result: MethodChannel.Result, setter: (T) -> Boolean) {
        if (arg == null ||
            (arg is Pair<*, *> && (arg.first == null || arg.second == null)) ||
            (arg is Triple<*, *, *> && (arg.first == null || arg.second == null || arg.third == null))
        ) {
            result.error("INVALID_ARGUMENT", "Argument cannot be null.", null)
            return
        }
        if (guardNotConnected(result)) return
        CoroutineScope(Dispatchers.IO).launch {
            val success = setter(arg)
            withContext(Dispatchers.Main) {
                result.success(success)
            }
        }
    }
}