plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val appVersion = Regex("(?m)^version: ([^+\\s]+)\\+(\\d+)")
    .find(rootProject.file("../pubspec.yaml").readText())
    ?: error("pubspec.yaml must contain version: name+code")

android {
    namespace = "com.manualcollector.manual_collector"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.manualcollector.manual_collector"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = appVersion.groupValues[2].toInt()
        versionName = appVersion.groupValues[1]
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Bundle Chinese OCR so first use works offline without Google Play Services.
dependencies {
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
