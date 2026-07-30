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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")

// jni 1.0.1 calls kotlin {} on AGP 9 without applying KGP when
// android.builtInKotlin=false (Flutter's temporary opt-out). Re-apply our patch
// before :jni evaluates so builds keep working after pub cache refreshes.
val jniProject = findProject(":jni")
if (jniProject != null) {
    val patched = file("patches/jni.build.gradle")
    val target = jniProject.projectDir.resolve("build.gradle")
    if (patched.exists() && target.exists()) {
        patched.copyTo(target, overwrite = true)
    }
}