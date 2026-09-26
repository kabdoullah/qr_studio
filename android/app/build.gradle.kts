import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Valeurs `--dart-define` de la compilation Flutter (encodées en base64 par
// l'outil), pour que l'application Dart et le SDK Facebook natif lisent la
// même configuration.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            String(Base64.getDecoder().decode(encoded)).split("=", limit = 2)
                .takeIf { it.size == 2 }
                ?.let { it[0] to it[1] }
        }
        ?.toMap()
        ?: emptyMap()

android {
    namespace = "com.qrstudio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Identifiants Facebook injectés en ressources (`resValue`).
    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifiant de l'application (Google Cloud, Meta, futur Play Store) :
        // le changer invalide les clients OAuth Android déjà configurés.
        applicationId = "com.qrstudio.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Le SDK Facebook s'initialise au lancement et bloque ses plugins sans
        // identifiants : sans configuration, des valeurs inertes sont
        // utilisées (le bouton Facebook est alors masqué côté Dart). Le
        // client token n'est pas un secret (il est embarqué par conception).
        resValue("string", "facebook_app_id", dartDefines["FACEBOOK_APP_ID"] ?: "0")
        resValue(
            "string",
            "facebook_client_token",
            dartDefines["FACEBOOK_CLIENT_TOKEN"] ?: "0",
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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
