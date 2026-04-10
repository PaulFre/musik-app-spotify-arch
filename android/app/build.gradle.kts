import java.net.URI
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    val dartDefines = (
        project.findProperty("dart-defines") as String?
            ?: project.findProperty("DART_DEFINES") as String?
            ?: System.getenv("DART_DEFINES")
    )
        ?.split(",")
        ?.mapNotNull { encoded ->
            runCatching {
                val decoded = String(Base64.getDecoder().decode(encoded))
                val separatorIndex = decoded.indexOf('=')
                if (separatorIndex <= 0) {
                    null
                } else {
                    decoded.substring(0, separatorIndex) to decoded.substring(separatorIndex + 1)
                }
            }.getOrNull()
        }
        ?.toMap()
        ?: emptyMap()
    val publicAppBaseUrl = dartDefines["PUBLIC_APP_BASE_URL"] ?: "https://party-queue.example"
    val publicAppBaseUri = URI(publicAppBaseUrl)
    val appLinkScheme = publicAppBaseUri.scheme ?: "https"
    val appLinkHost = publicAppBaseUri.host ?: "party-queue.example"

    namespace = "com.example.party_queue_app"
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
        applicationId = "com.example.party_queue_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLinkScheme"] = appLinkScheme
        manifestPlaceholders["appLinkHost"] = appLinkHost
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
