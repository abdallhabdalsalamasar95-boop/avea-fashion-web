pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
project(":app").projectDir = file("../admin_app/android/app")

val flutterProjectRoot = file("../admin_app")
val flutterPluginsFile = java.io.File(flutterProjectRoot, ".flutter-plugins-dependencies")
if (flutterPluginsFile.exists()) {
    val pluginsJson =
        groovy.json.JsonSlurper().parseText(flutterPluginsFile.readText()) as Map<*, *>
    val androidPlugins =
        ((pluginsJson["plugins"] as? Map<*, *>)?.get("android") as? List<*>) ?: emptyList<Any>()

    androidPlugins
        .mapNotNull { it as? Map<*, *> }
        .forEach { plugin ->
            val pluginName = plugin["name"] as? String ?: return@forEach
            val pluginPath = plugin["path"] as? String ?: return@forEach
            include(":$pluginName")
            project(":$pluginName").projectDir = java.io.File(pluginPath, "android")
        }
}
