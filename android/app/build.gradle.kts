plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

// App IDs per flavor.
val customerAppId = "com.aveafashion.app"
val adminAppId = "com.aveafashion.app.admin"

// Firebase (google-services.json): apply only when configured AND matching the
// requested flavor applicationId(s), so local/release builds don't fail due to
// a mismatched config file.
val googleServicesFile = file("google-services.json")
val googleServicesPackageNames = try {
    if (!googleServicesFile.exists()) {
        emptySet<String>()
    } else {
        val text = googleServicesFile.readText()
        Regex("\\\"package_name\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"")
            .findAll(text)
            .map { it.groupValues[1].trim() }
            .filter { it.isNotEmpty() }
            .toSet()
    }
} catch (_: Exception) {
    emptySet<String>()
}

val requestedTasksLower = gradle.startParameter.taskNames.joinToString(" ").lowercase()
val buildingAdminFlavor = requestedTasksLower.contains("admin")
val buildingCustomerFlavor = requestedTasksLower.contains("customer") || !buildingAdminFlavor

// The admin flavor is a dedicated WebView shell for the cloud dashboard and
// intentionally does not initialize Firebase. Only the customer app needs a
// matching google-services client.
val expectedAppIds = buildSet {
    if (buildingCustomerFlavor) add(customerAppId)
}

val googleServicesMatchesRequestedFlavor =
    expectedAppIds.any { googleServicesPackageNames.contains(it) }

// Don't allow accidental Play Store releases without a valid Firebase config.
// Debug builds can still run (Firebase will just not initialize).
val isReleaseTask = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val missingReleaseIds = expectedAppIds.filterNot { googleServicesPackageNames.contains(it) }
if (isReleaseTask && missingReleaseIds.isNotEmpty()) {
    throw GradleException(
        "Missing or mismatched android/app/google-services.json for release applicationId(s): " +
            missingReleaseIds.joinToString(", ") + ". " +
            "Download it from Firebase Console (Project settings → Your apps → Android) and place it at android/app/google-services.json. " +
            "(This file is intentionally gitignored.)",
    )
}
if (googleServicesMatchesRequestedFlavor) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    // TODO: Replace with your real package (must match Firebase + Play Console).
    namespace = "com.aveafashion.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // TODO: Replace with your real package (must match Firebase + Play Console).
        applicationId = customerAppId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "app"
    productFlavors {
        create("customer") {
            dimension = "app"
            applicationId = customerAppId
            resValue("string", "app_name", "AVEA FASHION")
        }
        create("admin") {
            dimension = "app"
            applicationId = adminAppId
            resValue("string", "app_name", "لوحة تحكم CARMEN KARLA")
        }
    }

    // Release signing (required for Play Store).
    // Create android/key.properties (NOT committed) based on android/key.properties.example.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasReleaseKeystore = keystorePropertiesFile.exists()
    if (hasReleaseKeystore) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    val isReleaseBundleTask = gradle.startParameter.taskNames.any {
        it.contains("bundle", ignoreCase = true) && it.contains("release", ignoreCase = true)
    }
    if (isReleaseBundleTask && !hasReleaseKeystore) {
        throw GradleException(
            "Google Play AAB requires a real upload keystore. " +
                "Create android/key.properties from android/key.properties.example and rebuild.",
        )
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = (keystoreProperties["keyAlias"] as String?)
                keyPassword = (keystoreProperties["keyPassword"] as String?)
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = (keystoreProperties["storePassword"] as String?)
            }
        }
    }

    buildTypes {
        release {
            // IMPORTANT: Play Store requires release signing.
            // If key.properties is missing we fallback to debug signing for local testing only.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Reduce APK/AAB size (R8 + resource shrinking).
            // Note: if you ever see a runtime crash only in release builds,
            // we may need to add additional keep rules in proguard-rules.pro.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // NOTE:
    // Do not add an explicit Play Core (com.google.android.play:core) dependency here.
    // Some plugins pull in com.google.android.play:core-common, and having both can
    // cause duplicate class errors during :app:checkDebugDuplicateClasses.
}
