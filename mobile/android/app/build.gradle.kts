import java.util.Properties
import java.io.FileInputStream

// 正式签名：存在 key.properties（CI/本地发版注入）时启用，否则回落 debug 签名（日常开发）。
val keystoreProperties = Properties().apply {
    val f = rootProject.file(System.getenv("KEY_PROPERTIES") ?: "key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

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
            signingConfig = if (hasReleaseKey) {
                signingConfigs.create("release") {
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    storeFile = file(keystoreProperties.getProperty("storeFile"))
                    storePassword = keystoreProperties.getProperty("storePassword")
                }
            } else {
                // 日常开发用 debug 签名，发版必须走 CI（签名校验见 tool/verify_signing.sh）。
                signingConfigs.getByName("debug")
            }
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
