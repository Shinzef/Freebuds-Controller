#include "core/device.h"
#include "core/types.h"
#include "platform/android/bluetooth_spp_client_android.h"
#include <android/log.h>
#include <iostream>
#include <jni.h>
#include <memory>
#include <sstream>
#include <string>
#include <vector> // Added for std::vector

#define LOGI(...) \
  __android_log_print(ANDROID_LOG_INFO, "JNI_BRIDGE", __VA_ARGS__)
#define LOGE(...) \
  __android_log_print(ANDROID_LOG_ERROR, "JNI_BRIDGE", __VA_ARGS__)

// Helper to get the C++ Device object from a Java long
static Device *get_device(jlong ptr) { return reinterpret_cast<Device *>(ptr); }

struct JniContext {
  JavaVM *vm = nullptr;
  jobject bluetoothManagerInstance;
  jmethodID connectMethodId;
  jmethodID findDeviceMethodId;
  jmethodID isConnectedMethodId;
  std::unique_ptr<Device> device;
};

// --- Lifecycle Functions ---
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
	JNIEnv *env;
	if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
		return -1;
	}
	LOGI("JNI_OnLoad called");
	return JNI_VERSION_1_6;
}

// Updated function name for Flutter package
extern "C" JNIEXPORT jlong JNICALL
Java_com_example_freebuds_1flutter_MainActivity_nativeInit(JNIEnv *env,
														   jobject thiz,
														   jobject bt_manager) {
	LOGI("nativeInit called");

	auto *context = new JniContext();
	env->GetJavaVM(&context->vm);

	context->bluetoothManagerInstance = env->NewGlobalRef(bt_manager);

	jclass managerClass = env->GetObjectClass(bt_manager);
	context->findDeviceMethodId = env->GetMethodID(
		managerClass, "findDeviceByName",
		"(Ljava/lang/String;)Landroid/bluetooth/BluetoothDevice;");
	context->connectMethodId =
		env->GetMethodID(managerClass, "connect", "(Ljava/lang/String;)Z");
	context->isConnectedMethodId =
		env->GetMethodID(managerClass, "isConnected", "()Z");

	env->DeleteLocalRef(managerClass);

	if (!context->findDeviceMethodId || !context->connectMethodId ||
		!context->isConnectedMethodId) {
		LOGE("Failed to find required methods");
		delete context;
		return 0;
	}

	LOGI("nativeInit successful");
	return reinterpret_cast<jlong>(context);
}

// Updated function name for Flutter package
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_freebuds_1flutter_MainActivity_nativeTestConnection(
	JNIEnv *env, jobject thiz, jlong instance_ptr, jstring device_name) {
	LOGI("nativeTestConnection called");

	JniContext *context = reinterpret_cast<JniContext *>(instance_ptr);
	if (!context) {
		LOGE("Invalid context");
		return false;
	}

	const char *name = env->GetStringUTFChars(device_name, nullptr);
	jstring jname = env->NewStringUTF(name);

	jboolean success = env->CallBooleanMethod(context->bluetoothManagerInstance,
											  context->connectMethodId, jname);

	env->ReleaseStringUTFChars(device_name, name);
	env->DeleteLocalRef(jname);

	LOGI("Connection result: %d", success);
	return success;
}

// Updated function name for Flutter package
extern "C" JNIEXPORT jlong JNICALL
Java_com_example_freebuds_1flutter_MainActivity_createDevice(
	JNIEnv *env, jobject thiz, jobject bt_manager) {
	LOGI("createDevice called");

	try {
		JavaVM *vm;
		env->GetJavaVM(&vm);

		auto bt_client =
			std::make_unique<BluetoothSppClientAndroid>(vm, bt_manager);
		auto device = std::make_unique<Device>(std::move(bt_client));

		LOGI("Device created successfully");
		return reinterpret_cast<jlong>(device.release());
	} catch (const std::exception &e) {
		LOGE("Exception in createDevice: %s", e.what());
		return 0;
	}
}

// Updated function name for Flutter package
extern "C" JNIEXPORT void JNICALL
Java_com_example_freebuds_1flutter_MainActivity_freeDevice(
	JNIEnv *env,jobject thiz,jlong device_ptr) {
	LOGI("freeDevice called");
	if (device_ptr != 0) {
		Device *device = reinterpret_cast<Device *>(device_ptr);
		delete device;
		LOGI("Device freed");
	}
}

// --- Connection Functions (NEW/MODIFIED) ---
extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeConnect(
	JNIEnv *env, jobject thiz, jlong device_ptr, jstring address) {
	if (device_ptr == 0)
	return false;
	const char *nativeAddress = env->GetStringUTFChars(address, nullptr);
	std::string addr_str(nativeAddress);
	env->ReleaseStringUTFChars(address, nativeAddress);
	LOGI("nativeConnect called for address: %s", addr_str.c_str());
	// Calling the C++ Device's connect method, which will delegate to Kotlin
	bool result = get_device(device_ptr)->connect(addr_str, 1);
	LOGI("nativeConnect result: %d", result);
	return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_freebuds_1flutter_MainActivity_nativeDisconnect(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
	if (device_ptr == 0)
		return;
	LOGI("nativeDisconnect called");
	get_device(device_ptr)->disconnect();
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeIsConnected(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
	if (device_ptr == 0)
		return false;
	return get_device(device_ptr)->is_connected();
}

// --- HELPERS FOR GESTURE ---
// Helper to convert C++ GestureAction enum to an integer for the UI
static int gestureActionToInt(GestureAction action) {
	switch (action) {
		case GestureAction::PLAY_PAUSE:
			return 1;
		case GestureAction::NEXT_TRACK:
			return 2;
		case GestureAction::PREV_TRACK:
			return 7;
		case GestureAction::VOICE_ASSISTANT:
			return 0;
		case GestureAction::OFF:
			return -1;
		case GestureAction::CHANGE_VOLUME:
			return 8; // Distinguishing from voice assistant
		case GestureAction::SWITCH_ANC:
			return 10;
		case GestureAction::ANSWER_CALL:
			return 11; // Distinguishing from voice assistant
		default:
			return -99; // Unknown
	}
}

// Helper to convert an integer from the UI to the C++ GestureAction enum
static GestureAction intToGestureAction(jint action) {
	switch (action) {
		case 1:
			return GestureAction::PLAY_PAUSE;
		case 2:
			return GestureAction::NEXT_TRACK;
		case 7:
			return GestureAction::PREV_TRACK;
		case 0:
			return GestureAction::VOICE_ASSISTANT;
		case -1:
			return GestureAction::OFF;
		case 8:
			return GestureAction::CHANGE_VOLUME;
		case 10:
			return GestureAction::SWITCH_ANC;
		case 11:
			return GestureAction::ANSWER_CALL;
		default:
			return GestureAction::UNKNOWN;
	}
}

// Helper to convert an integer from the UI to the C++ EarSide enum
static EarSide intToEarSide(jint side) {
return (side == 0) ? EarSide::LEFT : EarSide::RIGHT;
}

// --- Feature Functions ---
extern "C" JNIEXPORT jstring JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_getDeviceInfoFromNative(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
	LOGI("getDeviceInfoFromNative called");
	// Access the Device object directly from the pointer, not a global 'device'
	Device *device = reinterpret_cast<Device *>(device_ptr);
	if (device == nullptr || device_ptr == 0) {
		LOGE("Error: Null or invalid device pointer");
		return env->NewStringUTF("Error: Device not connected");
	}
	if (!device->is_connected()) {
		LOGE("Error: Device not connected");
		return env->NewStringUTF("Error: Device not connected");
	}
	auto device_info = device->get_device_info();
	if (!device_info) {
		LOGE("Error: Failed to get device info");
		return env->NewStringUTF("Error: Failed to get device info");
	}
	std::string info_str = "model: " + device_info->model + "\n" +
		"firmware_version: " + device_info->firmware_version +
		"\n" + "serial_number: " + device_info->serial_number;
	LOGI("Device info retrieved successfully");
	return env->NewStringUTF(info_str.c_str());
}

extern "C" JNIEXPORT jobject JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetGestureSettings(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return nullptr;

auto settings_opt = get_device(device_ptr)->get_all_gesture_settings();
if (!settings_opt) {
LOGE("Failed to get gesture settings");
return nullptr;
}
auto settings = settings_opt.value();

// Create a HashMap to return to Kotlin/Dart
jclass hashMapClass = env->FindClass("java/util/HashMap");
jmethodID hashMapCtor = env->GetMethodID(hashMapClass, "<init>", "()V");
jobject hashMap = env->NewObject(hashMapClass, hashMapCtor);
jmethodID putMethod = env->GetMethodID(
	hashMapClass, "put",
	"(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
jclass intClass = env->FindClass("java/lang/Integer");
jmethodID intCtor = env->GetMethodID(intClass, "<init>", "(I)V");

auto add_int_to_map = [&](const char *key, int value) {
  jstring jKey = env->NewStringUTF(key);
  jobject jValue = env->NewObject(intClass, intCtor, value);
  env->CallObjectMethod(hashMap, putMethod, jKey, jValue);
  env->DeleteLocalRef(jKey);
  env->DeleteLocalRef(jValue);
};

// Populate the map
add_int_to_map("double_tap_left",
gestureActionToInt(settings.double_tap_left));
add_int_to_map("double_tap_right",
gestureActionToInt(settings.double_tap_right));
add_int_to_map("triple_tap_left",
gestureActionToInt(settings.triple_tap_left));
add_int_to_map("triple_tap_right",
gestureActionToInt(settings.triple_tap_right));
add_int_to_map("long_tap_left", gestureActionToInt(settings.long_tap_left));
add_int_to_map("long_tap_right",
gestureActionToInt(settings.long_tap_right));
add_int_to_map("swipe_action", gestureActionToInt(settings.swipe_action));

env->DeleteLocalRef(hashMapClass);
env->DeleteLocalRef(intClass);

LOGI("Successfully retrieved gesture settings.");
return hashMap;
}

// Updated function name for Flutter package
extern "C" JNIEXPORT void JNICALL
Java_com_example_freebuds_1flutter_MainActivity_nativeCleanup(
	JNIEnv *env, jobject thiz, jlong instance_ptr) {
LOGI("nativeCleanup called");

if (instance_ptr != 0) {
JniContext *context = reinterpret_cast<JniContext *>(instance_ptr);
if (context->bluetoothManagerInstance) {
env->DeleteGlobalRef(context->bluetoothManagerInstance);
}
delete context;
LOGI("Native context cleaned up");
}
}

// Add missing functions that MainActivity expects
extern "C" JNIEXPORT jobject JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_getBatteryFromNative(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
LOGI("getBatteryFromNative called");

if (device_ptr == 0) {
LOGE("Invalid device pointer");
return nullptr;
}

Device *device = reinterpret_cast<Device *>(device_ptr);

if (!device->is_connected()) {
LOGE("Device not connected");
return nullptr;
}

try {
auto battery_info = device->get_battery_info();
if (!battery_info) {
LOGE("Failed to get battery info");
return nullptr;
}

// Create a HashMap to return
jclass hashMapClass = env->FindClass("java/util/HashMap");
jmethodID hashMapConstructor =
	env->GetMethodID(hashMapClass, "<init>", "()V");
jmethodID putMethod = env->GetMethodID(
	hashMapClass, "put",
	"(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

jobject hashMap = env->NewObject(hashMapClass, hashMapConstructor);

// Add battery levels to the map
jstring leftKey = env->NewStringUTF("left");
jstring rightKey = env->NewStringUTF("right");
jstring caseKey = env->NewStringUTF("case");

jclass integerClass = env->FindClass("java/lang/Integer");
jmethodID integerConstructor =
	env->GetMethodID(integerClass, "<init>", "(I)V");

// Corrected the member names to match the BatteryInfo struct
jobject leftValue =
	env->NewObject(integerClass, integerConstructor, battery_info->left);
jobject rightValue =
	env->NewObject(integerClass, integerConstructor, battery_info->right);
jobject caseValue = env->NewObject(integerClass, integerConstructor,
								   battery_info->case_level);

env->CallObjectMethod(hashMap, putMethod, leftKey, leftValue);
env->CallObjectMethod(hashMap, putMethod, rightKey, rightValue);
env->CallObjectMethod(hashMap, putMethod, caseKey, caseValue);

env->DeleteLocalRef(leftKey);
env->DeleteLocalRef(rightKey);
env->DeleteLocalRef(caseKey);
env->DeleteLocalRef(leftValue);
env->DeleteLocalRef(rightValue);
env->DeleteLocalRef(caseValue);
env->DeleteLocalRef(hashMapClass);
env->DeleteLocalRef(integerClass);

LOGI("Battery info retrieved successfully");
return hashMap;
} catch (const std::exception &e) {
LOGE("Exception in getBatteryFromNative: %s", e.what());
return nullptr;
}
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_setAncModeNative(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint mode) {
	LOGI("setAncModeNative called with mode: %d", mode);

	if (device_ptr == 0) {
		LOGE("Invalid device pointer");
		return false;
	}

	Device *device = reinterpret_cast<Device *>(device_ptr);

	if (!device->is_connected()) {
		LOGE("Device not connected");
		return false;
	}

	try {
		// Convert the integer mode from Flutter/Kotlin to the C++ AncMode enum
		AncMode anc_mode_to_set;
		switch (mode) {
			case 0: // OFF in the UI
				anc_mode_to_set = AncMode::NORMAL;
				break;
			case 1: // ON in the UI
				anc_mode_to_set = AncMode::CANCELLATION;
				break;
			case 2: // TRANSPARENCY in the UI
				anc_mode_to_set = AncMode::AWARENESS;
				break;
			default:
				LOGE("Invalid ANC mode: %d", mode);
				return false;
	}
		bool success = device->set_anc_mode(anc_mode_to_set);
		LOGI("ANC mode set result: %d", success);
		return success;
	} catch (const std::exception &e) {
		LOGE("Exception in setAncModeNative: %s", e.what());
		return false;
	}
}



extern "C" JNIEXPORT jobject JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetEqualizerInfo(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
	if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
	return nullptr;

	auto eq_info_opt = get_device(device_ptr)->get_equalizer_info();
	if (!eq_info_opt) {
		LOGE("Failed to get equalizer info");
		return nullptr;
	}
	auto eq_info = eq_info_opt.value();

	// Create the main HashMap to return
	jclass mapClass = env->FindClass("java/util/HashMap");
	jmethodID mapCtor = env->GetMethodID(mapClass, "<init>", "()V");
	jobject returnMap = env->NewObject(mapClass, mapCtor);
	jmethodID putMethod = env->GetMethodID(
		mapClass, "put",
		"(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

	// Add current_preset_id
	jclass intClass = env->FindClass("java/lang/Integer");
	jmethodID intCtor = env->GetMethodID(intClass, "<init>", "(I)V");
	jstring currentIdKey = env->NewStringUTF("current_preset_id");
	jobject currentIdValue =
		env->NewObject(intClass, intCtor, eq_info.current_preset_id);
	env->CallObjectMethod(returnMap, putMethod, currentIdKey, currentIdValue);
	env->DeleteLocalRef(currentIdKey);
	env->DeleteLocalRef(currentIdValue);

	// Add built_in_preset_ids
	jstring builtInIdsKey = env->NewStringUTF("built_in_preset_ids");
	jintArray builtInIdsArray =
		env->NewIntArray(eq_info.built_in_preset_ids.size());
	// Note: jint is not always the same as uint8_t, but for small numbers it's
	// fine. A proper conversion would be needed if values could be large.
	std::vector<jint> temp_built_in(eq_info.built_in_preset_ids.begin(),
									eq_info.built_in_preset_ids.end());
	env->SetIntArrayRegion(builtInIdsArray, 0, temp_built_in.size(),
		temp_built_in.data());
	env->CallObjectMethod(returnMap, putMethod, builtInIdsKey, builtInIdsArray);
	env->DeleteLocalRef(builtInIdsKey);
	env->DeleteLocalRef(builtInIdsArray);

	// Add custom_presets (as a List of Maps)
	jstring customPresetsKey = env->NewStringUTF("custom_presets");
	jclass listClass = env->FindClass("java/util/ArrayList");
	jmethodID listCtor = env->GetMethodID(listClass, "<init>", "()V");
	jobject customPresetsList = env->NewObject(listClass, listCtor);
	jmethodID addMethod =
		env->GetMethodID(listClass, "add", "(Ljava/lang/Object;)Z");

	for (const auto &preset : eq_info.custom_presets) {
	jobject presetMap = env->NewObject(mapClass, mapCtor);

	// Add id to preset map
	jstring idKey = env->NewStringUTF("id");
	jobject idValue = env->NewObject(intClass, intCtor, preset.id);
	env->CallObjectMethod(presetMap, putMethod, idKey, idValue);
	env->DeleteLocalRef(idKey);
	env->DeleteLocalRef(idValue);

	// Add name to preset map
	jstring nameKey = env->NewStringUTF("name");
	jstring nameValue = env->NewStringUTF(preset.name.c_str());
	env->CallObjectMethod(presetMap, putMethod, nameKey, nameValue);
	env->DeleteLocalRef(nameKey);
	env->DeleteLocalRef(nameValue);

	// Add values array to preset map
	jstring valuesKey = env->NewStringUTF("values");
	jintArray valuesArray = env->NewIntArray(preset.values.size());
	std::vector<jint> temp_values(preset.values.begin(), preset.values.end());
	env->SetIntArrayRegion(valuesArray, 0, temp_values.size(),
		temp_values.data());
	env->CallObjectMethod(presetMap, putMethod, valuesKey, valuesArray);
	env->DeleteLocalRef(valuesKey);
	env->DeleteLocalRef(valuesArray);

	// Add the completed presetMap to the list
	env->CallBooleanMethod(customPresetsList, addMethod, presetMap);
	env->DeleteLocalRef(presetMap);
	}
	env->CallObjectMethod(returnMap, putMethod, customPresetsKey,
		customPresetsList);
	env->DeleteLocalRef(customPresetsKey);
	env->DeleteLocalRef(customPresetsList);

	// Cleanup
	env->DeleteLocalRef(mapClass);
	env->DeleteLocalRef(intClass);
	env->DeleteLocalRef(listClass);

	LOGI("Successfully retrieved equalizer info.");
	return returnMap;
	}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetEqualizerPreset(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint preset_id) {
	if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
		return false;
	LOGI("nativeSetEqualizerPreset called with id: %d", preset_id);
	return get_device(device_ptr)->set_equalizer_preset(
	static_cast<uint8_t>(preset_id));
}

// --- END OF EQUALIZER CONTROL ---
extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetWearDetectionStatus(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
	if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
		return false;
	auto status = get_device(device_ptr)->get_wear_detection_status();
	return status.has_value() && status.value();
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetWearDetection(
	JNIEnv *env, jobject thiz, jlong device_ptr, jboolean enable) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetWearDetection called with: %d", enable);
return get_device(device_ptr)->set_wear_detection(enable);
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetLowLatencyStatus(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
auto status = get_device(device_ptr)->get_low_latency_status();
return status.has_value() && status.value();
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetLowLatency(
	JNIEnv *env, jobject thiz, jlong device_ptr, jboolean enable) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetLowLatency called with: %d", enable);
return get_device(device_ptr)->set_low_latency(enable);
}

extern "C" JNIEXPORT jint JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetSoundQuality(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return 0; // Default to "Connection"
auto pref = get_device(device_ptr)->get_sound_quality_preference();
if (pref.has_value()) {
return static_cast<jint>(pref.value());
}
return 0;
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetSoundQuality(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint preference) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetSoundQuality called with: %d", preference);
auto pref_enum = static_cast<SoundQualityPreference>(preference);
return get_device(device_ptr)->set_sound_quality_preference(pref_enum);
}

extern "C" JNIEXPORT jobject JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetAncStatus(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return nullptr;

auto status_opt = get_device(device_ptr)->get_anc_status();
if (!status_opt) {
return nullptr;
}
auto status = status_opt.value();

LOGI("Raw ANC status - mode: %d, level: %d", static_cast<int>(status.mode),
	 static_cast<int>(status.level));

jclass hashMapClass = env->FindClass("java/util/HashMap");
jmethodID hashMapCtor = env->GetMethodID(hashMapClass, "<init>", "()V");
jobject hashMap = env->NewObject(hashMapClass, hashMapCtor);
jmethodID putMethod = env->GetMethodID(
	hashMapClass, "put",
	"(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
jclass intClass = env->FindClass("java/lang/Integer");
jmethodID intCtor = env->GetMethodID(intClass, "<init>", "(I)V");

auto add_int_to_map = [&](const char *key, int value) {
  jstring jKey = env->NewStringUTF(key);
  jobject jValue = env->NewObject(intClass, intCtor, value);
  env->CallObjectMethod(hashMap, putMethod, jKey, jValue);
  env->DeleteLocalRef(jKey);
  env->DeleteLocalRef(jValue);
};

int flutter_mode = 0;
switch (status.mode) {
case AncMode::NORMAL:
flutter_mode = 0;
break;
case AncMode::CANCELLATION:
flutter_mode = 1;
break;
case AncMode::AWARENESS:
flutter_mode = 2;
break;
default:
flutter_mode = 0;
break;
}

// For awareness mode, we'll use a boolean approach
bool is_voice_boost = false;
int flutter_level = 0;

if (status.mode == AncMode::AWARENESS) {
is_voice_boost = (status.level == AncLevel::VOICE_BOOST);
flutter_level =
is_voice_boost ? 1 : 0; // 1 = voice boost on, 0 = voice boost off
} else if (status.mode == AncMode::CANCELLATION) {
switch (status.level) {
case AncLevel::COMFORTABLE:
flutter_level = 0;
break;
case AncLevel::NORMAL_CANCELLATION:
flutter_level = 1;
break;
case AncLevel::ULTRA:
flutter_level = 2;
break;
case AncLevel::DYNAMIC:
flutter_level = 3;
break;
default:
flutter_level = 0;
break;
}
}

LOGI("Converted to Flutter - mode: %d, level: %d", flutter_mode,
	 flutter_level);

add_int_to_map("mode", flutter_mode);
add_int_to_map("level", flutter_level);

env->DeleteLocalRef(hashMapClass);
env->DeleteLocalRef(intClass);

return hashMap;
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetAncLevel(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint level) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetAncLevel called with: %d", level);

AncLevel level_enum;
switch (level) {
case 0:
level_enum = AncLevel::COMFORTABLE;
break;
case 1:
level_enum = AncLevel::NORMAL_CANCELLATION;
break;
case 2:
level_enum = AncLevel::ULTRA;
break;
case 3:
level_enum = AncLevel::DYNAMIC;
break;
case 4:
level_enum = AncLevel::VOICE_BOOST;
break; // Voice Boost ON
case 6:
level_enum = AncLevel::NORMAL_AWARENESS;
break; // Normal Awareness (Voice Boost OFF)
default:
LOGE("Invalid ANC level: %d", level);
return false;
}

return get_device(device_ptr)->set_anc_level(level_enum);
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetDoubleTapAction(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint side, jint action) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetDoubleTapAction called with side: %d, action: %d", side,
	 action);
return get_device(device_ptr)->set_double_tap_action(
	intToEarSide(side), intToGestureAction(action));
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetTripleTapAction(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint side, jint action) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetTripleTapAction called with side: %d, action: %d", side,
	 action);
return get_device(device_ptr)->set_triple_tap_action(
	intToEarSide(side), intToGestureAction(action));
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetLongTapAction(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint side, jint action) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetLongTapAction called with side: %d, action: %d", side, action);
return get_device(device_ptr)->set_long_tap_action(
	intToEarSide(side), intToGestureAction(action));
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeSetSwipeAction(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint action) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
LOGI("nativeSetSwipeAction called with action: %d", action);
return get_device(device_ptr)->set_swipe_action(intToGestureAction(action));
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeCreateOrUpdateCustomEqualizer(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint id, jstring name,
	jintArray values) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;

CustomEqPreset preset;
preset.id = static_cast<uint8_t>(id);

const char *name_chars = env->GetStringUTFChars(name, nullptr);
preset.name = std::string(name_chars);
env->ReleaseStringUTFChars(name, name_chars);

jsize len = env->GetArrayLength(values);
if (len != 10) {
LOGE("Custom EQ must have 10 values, but got %d", len);
return false;
}
jint *value_elements = env->GetIntArrayElements(values, nullptr);
for (int i = 0; i < len; ++i) {
preset.values.push_back(static_cast<int8_t>(value_elements[i]));
}
env->ReleaseIntArrayElements(values, value_elements, JNI_ABORT);

LOGI("Calling create_or_update_custom_equalizer with id: %d, name: %s", id,
	 preset.name.c_str());
return get_device(device_ptr)->create_or_update_custom_equalizer(preset);
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeDeleteCustomEqualizer(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint id, jstring name,
	jintArray values) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;

// We must construct the full preset object to pass to the command writer.
CustomEqPreset preset_to_delete;
preset_to_delete.id = static_cast<uint8_t>(id);

const char *name_chars = env->GetStringUTFChars(name, nullptr);
preset_to_delete.name = std::string(name_chars);
env->ReleaseStringUTFChars(name, name_chars);

jsize len = env->GetArrayLength(values);
if (len != 10)
return false; // Safety check
jint *value_elements = env->GetIntArrayElements(values, nullptr);
for (int i = 0; i < len; ++i) {
preset_to_delete.values.push_back(static_cast<int8_t>(value_elements[i]));
}
env->ReleaseIntArrayElements(values, value_elements, JNI_ABORT);

LOGI("Calling delete_custom_equalizer with full payload for id: %d", id);
return get_device(device_ptr)->delete_custom_equalizer(preset_to_delete);
}

extern "C" JNIEXPORT jobject JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeGetDualConnectDevices(
	JNIEnv *env, jobject thiz, jlong device_ptr) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return nullptr;

auto devices = get_device(device_ptr)->get_dual_connect_devices();

// Create a Java ArrayList to hold our device maps
jclass listClass = env->FindClass("java/util/ArrayList");
jmethodID listCtor = env->GetMethodID(listClass, "<init>", "()V");
jobject deviceList = env->NewObject(listClass, listCtor);
jmethodID addMethod =
	env->GetMethodID(listClass, "add", "(Ljava/lang/Object;)Z");

jclass mapClass = env->FindClass("java/util/HashMap");
jmethodID mapCtor = env->GetMethodID(mapClass, "<init>", "()V");
jmethodID putMethod = env->GetMethodID(
	mapClass, "put",
	"(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

for (const auto &device : devices) {
jobject deviceMap = env->NewObject(mapClass, mapCtor);

// Helper lambda to add a string to the map
auto add_string_to_map = [&](const char *key, const std::string &value) {
  jstring jKey = env->NewStringUTF(key);
  jstring jValue = env->NewStringUTF(value.c_str());
  env->CallObjectMethod(deviceMap, putMethod, jKey, jValue);
  env->DeleteLocalRef(jKey);
  env->DeleteLocalRef(jValue);
};

// Helper lambda to add a boolean to the map
auto add_bool_to_map = [&](const char *key, bool value) {
  jclass boolClass = env->FindClass("java/lang/Boolean");
  jmethodID boolCtor = env->GetMethodID(boolClass, "<init>", "(Z)V");
  jstring jKey = env->NewStringUTF(key);
  jobject jValue = env->NewObject(boolClass, boolCtor, value);
  env->CallObjectMethod(deviceMap, putMethod, jKey, jValue);
  env->DeleteLocalRef(jKey);
  env->DeleteLocalRef(jValue);
  env->DeleteLocalRef(boolClass);
};

add_string_to_map("mac_address", device.mac_address);
add_string_to_map("name", device.name);
add_bool_to_map("is_connected", device.is_connected);
add_bool_to_map("is_playing", device.is_playing);
add_bool_to_map("is_preferred", device.is_preferred);

env->CallBooleanMethod(deviceList, addMethod, deviceMap);
env->DeleteLocalRef(deviceMap);
}

env->DeleteLocalRef(listClass);
env->DeleteLocalRef(mapClass);

return deviceList;
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_nativeDualConnectAction(
	JNIEnv *env, jobject thiz, jlong device_ptr, jstring mac_address,
jint action_code) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;

const char *mac_chars = env->GetStringUTFChars(mac_address, nullptr);
std::string mac_str(mac_chars);
env->ReleaseStringUTFChars(mac_address, mac_chars);

LOGI("nativeDualConnectAction called for MAC: %s with action: %d",
	 mac_str.c_str(), action_code);
return get_device(device_ptr)->dual_connect_action(
	mac_str, static_cast<uint8_t>(action_code));
}

extern "C" JNIEXPORT jboolean JNICALL
	Java_com_example_freebuds_1flutter_MainActivity_createFakePreset(
	JNIEnv *env, jobject thiz, jlong device_ptr, jint preset_type,
jint new_id) {
if (device_ptr == 0 || !get_device(device_ptr)->is_connected())
return false;
FakePreset type =
	(preset_type == 0) ? FakePreset::SYMPHONY : FakePreset::HI_FI_LIVE;
return get_device(device_ptr)->create_fake_preset(type,
static_cast<uint8_t>(new_id));
}
