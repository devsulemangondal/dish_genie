import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.dishgenie.recipeapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    defaultConfig {
        applicationId = "com.dishgenie.recipeapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // UMP (GDPR) debug helpers (ONLY for testing)
            buildConfigField("boolean", "UMP_DEBUG_FORCE_EEA", "false")
            buildConfigField("String", "UMP_TEST_DEVICE_HASHED_ID", "\"\"")
        }
        release {
            // Release MUST NOT force EEA / test devices
            buildConfigField("boolean", "UMP_DEBUG_FORCE_EEA", "false")
            buildConfigField("String", "UMP_TEST_DEVICE_HASHED_ID", "\"\"")
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
  // Use BOM so all Firebase libs (from Flutter plugins) share one version. Do not add duplicate
  // implementation("com.google.firebase:firebase-analytics") here—Flutter firebase_analytics plugin provides it; duplicate can cause crash on launch.
  implementation(platform("com.google.firebase:firebase-bom:34.6.0"))

  // Google User Messaging Platform (UMP) SDK for GDPR consent (AdMob).
  // Ref: https://developers.google.com/ad-manager/mobile-ads-sdk/android/privacy
  implementation("com.google.android.ump:user-messaging-platform:4.0.0")
}