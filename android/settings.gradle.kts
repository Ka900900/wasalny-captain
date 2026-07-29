pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = java.io.File(rootDir, "local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.reader().use { properties.load(it) }
        }
        val flutterSdk = properties.getProperty("flutter.sdk")
        require(flutterSdk != null) { "flutter.sdk not set in local.properties" }
        flutterSdk
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
    
    // 👈 تحديث AGP إلى 8.11.1 لتلبية متطلبات Flutter و AndroidX
    id("com.android.application") version "8.11.1" apply false
    
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
    // END: FlutterFire Configuration
    
    // 👈 تحديث Kotlin إلى 2.2.20
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")