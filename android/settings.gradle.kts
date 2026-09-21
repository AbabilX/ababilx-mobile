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

// flutter_callkit_incoming 3.1.3 owns its ringtone + notification managers in
// the FlutterPlugin instance. A data-only FCM background engine detaches about
// two seconds after showing an incoming call; upstream then destroys those
// managers even though its full-screen Activity and persisted active call are
// still alive. Result: ringtone stops, and Decline cannot clear the tray
// notification because the BroadcastReceiver finds a null manager.
//
// Keep the native managers for the Android process lifetime. Checking
// ACTIVE_CALLS here still has a race: showCallkitIncoming sends a broadcast and
// can detach before that receiver persists the call. The receiver already
// stops sound/notifications on accept, decline, timeout and end, so retaining
// two idle manager objects is safe. This is an exact-source patch pinned to
// 3.1.3; fail the build if upstream changes so the bug cannot silently return.
gradle.beforeProject {
    if (name == "flutter_callkit_incoming") {
        val target = projectDir.resolve(
            "src/main/kotlin/com/hiennv/flutter_callkit_incoming/FlutterCallkitIncomingPlugin.kt",
        )
        check(target.exists()) { "flutter_callkit_incoming 3.1.3 source is missing" }
        val oldBlock = listOf(
            "        if (methodChannels.isEmpty() && eventChannels.isEmpty()) {",
            "            instance.callkitSoundPlayerManager?.destroy()",
            "            instance.callkitNotificationManager?.destroy()",
            "            instance.callkitSoundPlayerManager = null",
            "            instance.callkitNotificationManager = null",
            "        }",
        ).joinToString("\n")
        val activeCallGuardBlock = listOf(
            "        if (methodChannels.isEmpty() && eventChannels.isEmpty()) {",
            "            val hasActiveNativeCalls = getDataActiveCalls(instance.context).isNotEmpty()",
            "            if (!hasActiveNativeCalls) {",
            "                instance.callkitSoundPlayerManager?.destroy()",
            "                instance.callkitNotificationManager?.destroy()",
            "                instance.callkitSoundPlayerManager = null",
            "                instance.callkitNotificationManager = null",
            "            }",
            "        }",
        ).joinToString("\n")
        val patchedBlock = listOf(
            "        if (methodChannels.isEmpty() && eventChannels.isEmpty()) {",
            "            // Native call UI can outlive a short-lived FCM FlutterEngine.",
            "            // Keep managers; call actions stop their sound and notifications.",
            "        }",
        ).joinToString("\n")
        val source = target.readText()
        when {
            source.contains(patchedBlock) -> Unit
            source.contains(oldBlock) -> target.writeText(source.replace(oldBlock, patchedBlock))
            source.contains(activeCallGuardBlock) ->
                target.writeText(source.replace(activeCallGuardBlock, patchedBlock))
            else -> error("flutter_callkit_incoming lifecycle patch no longer matches 3.1.3")
        }
    }
}

apply(from = "patches/callkit-accept.gradle")
apply(from = "patches/callkit-lifecycle.gradle")
apply(from = "patches/callkit-incoming-ui.gradle")
apply(from = "patches/flutter-webrtc-projection-stop.gradle")
