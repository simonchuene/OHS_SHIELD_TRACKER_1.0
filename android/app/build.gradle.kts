plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging (Prompt 15/18): enable AFTER adding a per-env
    // google-services.json to android/app/. Left disabled so the base build
    // works without Firebase config (FcmService degrades gracefully).
    // id("com.google.gms.google-services")
}

android {
    namespace = "com.ohsshield.ohs_shield_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ohsshield.ohs_shield_tracker"
        // minSdk 23: required by flutter_secure_storage (encryptedSharedPreferences)
        // and comfortably covers geolocator/firebase_messaging (21+).
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Per-environment flavors (Prompt 18). Build with e.g.
    //   flutter build apk --flavor dev  --dart-define-from-file=config/env/dev.json
    // Distinct applicationId suffixes let dev/uat/prod coexist on one device.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("uat") {
            dimension = "env"
            applicationIdSuffix = ".uat"
            versionNameSuffix = "-uat"
        }
        create("prod") {
            dimension = "env"
        }
    }

    buildTypes {
        release {
            // TODO: Replace with a real release signing config before store upload.
            // Debug-signed for now so `flutter build --release` works locally.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
