plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val flutterVersionCode = project.findProperty("flutter.versionCode")?.toString() ?: "1"
val flutterVersionName = project.findProperty("flutter.versionName")?.toString() ?: "1.0"

android {
    namespace = "com.example.freebuds_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.freebuds_flutter"
        minSdk = 21 // Minimum for Bluetooth permissions
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName

        // For C++ native code (if you're using JNI)
        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_shared"
            }
        }

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        getByName("release") {
            // Replace with your own signing config later
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures {
        // Add this if you're using ViewBinding or Compose, otherwise remove it
        // viewBinding = true
    }
}

flutter {
    source = "../.."
}
