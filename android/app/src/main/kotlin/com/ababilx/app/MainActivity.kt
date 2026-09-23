package com.ababilx.app

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.core.view.WindowCompat
import com.ababilx.app.mediasend.MediaSendChannel
import com.ababilx.call_ringer.CallRinger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** A call answered on a locked phone runs over the keyguard; nothing else does. */
    private val callLockScreen by lazy { CallLockScreen(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge to edge on every version, not only the Android 15 default:
        // Flutter reads the bars as viewPadding and every screen already pads
        // for them. After super, which paints its own translucent status bar
        // below API 35. This is also the call Play Console looks for.
        WindowCompat.enableEdgeToEdge(window)
        // After super, because its cover goes over the FlutterView. A recreated
        // Activity still carries its old intent, and that is not a new Accept.
        if (savedInstanceState == null) callLockScreen.handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        callLockScreen.refresh()
    }

    /** Incoming ACTION_SEND from another app's share sheet. */
    private val shareIntake by lazy { ShareIntakeChannel(this) }

    /** Ongoing-call notification: return to the call, or hang up from the shade. */
    private val ongoingCall by lazy { OngoingCallChannel(this) }

    /** Shrinks a live call into a floating window, the way Signal does. */
    private val pip by lazy { PipController(this) }

    /** Proximity blanking at the ear, and no screen timeout on a call screen. */
    private val callScreenLock by lazy { CallScreenLock(this) }

    /** MediaStore behind the in-app photo grid (composer + avatar picker). */
    private val mediaGallery by lazy { MediaGalleryChannel(this) }

    /** Signal-style picker, review and editor, drawn natively. */
    private val mediaSend by lazy { MediaSendChannel(this) }

    /** Alternate launcher icons, switched via activity-alias. */
    private val appIcon by lazy { AppIconChannel(applicationContext) }

    /** Keystore-backed SQLCipher history; Android is the source of truth. */
    private val chatStore by lazy { ChatMessageStoreChannel(applicationContext) }

    /** Doze, Data Saver and background-restricted state behind the vitals check. */
    private val battery by lazy { BatteryOptimizationChannel(this) }

    /** Video poster frames, and no screen timeout while one is playing. */
    private val video by lazy { VideoPlaybackChannel(this) }

    /** Roaming, which connectivity_plus cannot see — gates media auto-download. */
    private val networkState by lazy { NetworkStateChannel(applicationContext) }

    /** An explicit Save into Downloads or the gallery — never automatic. */
    private val mediaStore by lazy { MediaStoreChannel(this) }

    /** Speaker / earpiece for a call Android Telecom hosts — a CallKit Answer. */
    private val callAudioTelecom by lazy { CallAudioTelecom() }

    /** FLAG_SECURE while a Ghost Chat is on screen. */
    private val secureWindow by lazy { SecureWindowChannel(this) }

    /** Ghost Chat files, held in memory and opened without touching disk. */
    private val ghostBlobs by lazy { GhostBlobChannel(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDeviceChannel(flutterEngine)
        callLockScreen.attach(flutterEngine)
        shareIntake.attach(flutterEngine)
        // The share that launched us is already on the Activity's intent by
        // the time the engine is configured, and never arrives as onNewIntent.
        shareIntake.handleIntent(intent, initial = true)
        ongoingCall.attach(flutterEngine)
        // Launched by a tap on the ongoing-call notification while the process
        // was dead: that intent is already on the Activity and never arrives
        // as onNewIntent, same as a cold-start share.
        ongoingCall.handleIntent(intent)
        pip.attach(flutterEngine)
        callScreenLock.attach(flutterEngine)
        callAudioTelecom.attach(flutterEngine)
        mediaGallery.attach(flutterEngine)
        mediaSend.attach(flutterEngine)
        appIcon.attach(flutterEngine)
        chatStore.attach(flutterEngine)
        battery.attach(flutterEngine)
        video.attach(flutterEngine)
        networkState.attach(flutterEngine)
        mediaStore.attach(flutterEngine)
        secureWindow.attach(flutterEngine)
        ghostBlobs.attach(flutterEngine)
    }

    /**
     * Identity of this handset for push registration.
     *
     * ANDROID_ID survives a reinstall for the same signing key, so the server
     * can drop the `device_tokens` rows this phone left behind under earlier
     * FCM tokens — those stale rows are what delivered every push twice.
     */
    @SuppressLint("HardwareIds")
    private fun configureDeviceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ababilx.app/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceId" -> result.success(
                    Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "",
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // The media-send flow answers its own MethodChannel call; anything
        // else belongs to a Flutter plugin and must keep going to super.
        if (mediaSend.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    /**
     * A share arriving while the app is already running. launchMode is
     * singleTop and MainActivity is the only *launchable* Activity (the
     * media-send flow is internal and never receives a share), so the share
     * always lands here rather than building a second Flutter engine.
     */
    override fun onNewIntent(intent: Intent) {
        // First: the flag has to be up before the Activity comes forward.
        callLockScreen.handleIntent(intent)
        super.onNewIntent(intent)
        shareIntake.handleIntent(intent, initial = false)
        ongoingCall.handleIntent(intent)
    }

    /**
     * Home pressed. [PipController] shrinks the window only while a call is on
     * screen; every other time this is a no-op and the app just backgrounds.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        pip.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pip.onPipModeChanged(isInPictureInPictureMode)
    }

    override fun onDestroy() {
        // The in-app call screen died with the Activity; CallKit's own hold is
        // untouched, so a call ringing natively keeps ringing.
        CallRinger.release(FLUTTER_HOLDER)
        // The connected call died with it too, and less obviously: the WebRTC
        // session lives in the FlutterEngine, which this Activity owns. The
        // foreground service does not — it survives in the process and kept
        // showing "Ongoing call" for a call that no longer existed, with no
        // return bar in the app and nothing behind the notification's tap.
        // `stopWithTask` only covers the task being swiped away; the OS
        // reclaiming the Activity (or "Don't keep activities") is this case.
        OngoingCallService.stop(this)
        shareIntake.dispose()
        ongoingCall.dispose()
        pip.dispose()
        // Releases the proximity lock: a wake lock outliving the Activity would
        // keep the panel dark with no call left to justify it.
        callScreenLock.dispose()
        callLockScreen.dispose()
        mediaGallery.dispose()
        mediaSend.dispose()
        appIcon.dispose()
        chatStore.dispose()
        battery.dispose()
        networkState.dispose()
        super.onDestroy()
    }

    companion object {
        /** Ring holder for the in-app call screen — mirrors `ring_holders.dart`. */
        private const val FLUTTER_HOLDER = "flutter"
    }
}
