import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets live in android/local.properties (gitignored), e.g. GOOGLE_MAPS_API_KEY=AIza...
// Plain statements on purpose: inside a Gradle script, `apply {}` and `java.` resolve to Gradle's
// own Project.apply and `java` extension rather than Kotlin's scope function and package.
val localProps = Properties()
val localPropsFile = rootProject.file("local.properties")
if (localPropsFile.exists()) {
    FileInputStream(localPropsFile).use { stream -> localProps.load(stream) }
}

// Release signing reads android/key.properties (gitignored):
//   storeFile=/absolute/path/upload-keystore.jks
//   storePassword=…  keyAlias=upload  keyPassword=…
// Without it, release builds fall back to the debug key, which Play rejects.
val keystoreProps = Properties()
val keystorePropsFile = rootProject.file("key.properties")
if (keystorePropsFile.exists()) {
    FileInputStream(keystorePropsFile).use { stream -> keystoreProps.load(stream) }
}

android {
    namespace = "com.brilliantdisruptions.canvas_route"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (follow-up reminders) needs Java 8+ APIs on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published to Play.
        applicationId = "com.brilliantdisruptions.canvas_route"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Pass --dart-define=GOOGLE_MAPS_API_KEY=... ; falls back to a local.properties key.
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = localProps.getProperty("GOOGLE_MAPS_API_KEY")
            ?: (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)
            ?: System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
    }

    signingConfigs {
        create("release") {
            if (keystorePropsFile.exists()) {
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropsFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found: signing release with the DEBUG key (not uploadable to Play)")
                signingConfigs.getByName("debug")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
