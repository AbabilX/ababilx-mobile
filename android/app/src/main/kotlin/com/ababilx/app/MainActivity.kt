package com.ababilx.app

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.core.view.WindowCompat
import com.ababilx.app.backup.LocalBackupChannel
import com.ababilx.app.callaudio.CallAudioSession
import com.ababilx.app.localshare.LocalShareFolderChannel
import com.ababilx.app.historysync.HistorySyncChannel
import com.ababilx.app.localshare.LocalShareNetChannel
import com.ababilx.app.mediasend.MediaSendChannel
import com.ababilx.call_ringer.CallRinger
import com.hiennv.flutter_callkit_incoming.CallkitRingSilence
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
        LaunchSplashTheme.apply(this)
        // After super, because its cover goes over the FlutterView. A recreated
        // Activity still carries its old intent, and that is not a new Accept.
        if (savedInstanceState == null) callLockScreen.handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        callLockScreen.onResume()
    }

    /** The volume-key press that silenced a ring; its release is ours too. */
    private var silencingKey: Int? = null

    /**
     * A volume key while a call rings silences it, as the phone's own dialer
     * does; the call keeps ringing on screen. Checked before Flutter sees the
     * key. Only the first press is taken: once the ring is quiet, volume keys
     * are volume again (so a live call's volume is never held hostage).
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val volumeKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_UP
        if (volumeKey) {
            if (event.action == KeyEvent.ACTION_DOWN && CallRinger.isSilenceable()) {
                silencingKey = event.keyCode
                CallkitRingSilence.request()
                return true
            }
            if (event.action == KeyEvent.ACTION_UP && silencingKey == event.keyCode) {
                silencingKey = null
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onStop() {
        super.onStop()
        callLockScreen.onStop()
    }

    /** Incoming ACTION_SEND from another app's share sheet. */
    private val shareIntake by lazy { ShareIntakeChannel(this) }

    /** Ongoing-call notification: return to the call, or hang up from the shade. */
    private val ongoingCall by lazy { OngoingCallChannel(applicationContext) }

    /** Shrinks a live call into a floating window, the way Signal does. */
    private val pip by lazy { PipController(this) }

    /** Proximity blanking at the ear, and no screen timeout on a call screen. */
    private val callScreenLock by lazy { CallScreenLock(this) }

    /** The caller's ringback tone while the other phone rings. */
    private val callRingback by lazy { CallRingback(this) }

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
    private val callHaptics by lazy { CallHapticsChannel(applicationContext) }

    /** An explicit Save into Downloads or the gallery — never automatic. */
    private val mediaStore by lazy { MediaStoreChannel(this) }

    /** FLAG_SECURE while a Ghost Chat is on screen. */
    private val secureWindow by lazy { SecureWindowChannel(this) }

    /** Ghost Chat files, held in memory and opened without touching disk. */
    private val ghostBlobs by lazy { GhostBlobChannel(this) }

    /** Fingerprint, face or screen lock for a locked chat. */
    private val deviceAuth by lazy { DeviceAuthChannel(this) }

    /** Local backup folder and file pickers (features/local-backup). */
    private val localBackup by lazy { LocalBackupChannel(this) }

    /** Local Share: Wi-Fi locks + the transfer service (features/local_share). */
    private val localShareNet by lazy { LocalShareNetChannel(applicationContext) }
    private val historySync by lazy { HistorySyncChannel(applicationContext) }

    /** Local Share: sending a whole folder. */
    private val localShareFolder by lazy { LocalShareFolderChannel(this) }

    /** This Activity runs on an engine a live call carried past the last one. */
    private var engineReused = false

    /** Set in [onDestroy]: a call is live, so the engine outlives this Activity. */
    private var keepEngine = false

    /**
     * The engine of a call still running from a previous Activity — swiped out
     * of Recents, or reclaimed by the OS — or null for a fresh one.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val kept = CallEngineKeeper.take() ?: return null
        engineReused = true
        return kept
    }

    override fun shouldDestroyEngineWithHost(): Boolean = !keepEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDeviceChannel(flutterEngine)
        callLockScreen.attach(flutterEngine)
        shareIntake.attach(flutterEngine)
        // The share that launched us is already on the Activity's intent by
        // the time the engine is configured, and never arrives as onNewIntent.
        shareIntake.handleIntent(intent, initial = true)
        // Engine-scoped: a reused engine still has its handlers, and Dart's
        // event subscription with them.
        if (!engineReused) ongoingCall.attach(flutterEngine)
        // Launched by a tap on the ongoing-call notification while the process
        // was dead: that intent is already on the Activity and never arrives
        // as onNewIntent, same as a cold-start share.
        ongoingCall.handleIntent(intent)
        pip.attach(flutterEngine)
        callScreenLock.attach(flutterEngine)
        callRingback.attach(flutterEngine)
        // The call's one audio owner: mode, focus, earpiece / speaker /
        // Bluetooth / wired (Signal's SignalAudioManager).
        CallAudioSession.attach(flutterEngine, this)
        mediaGallery.attach(flutterEngine)
        mediaSend.attach(flutterEngine)
        appIcon.attach(flutterEngine)
        chatStore.attach(flutterEngine)
        battery.attach(flutterEngine)
        video.attach(flutterEngine)
        networkState.attach(flutterEngine)
        callHaptics.attach(flutterEngine)
        mediaStore.attach(flutterEngine)
        secureWindow.attach(flutterEngine)
        ghostBlobs.attach(flutterEngine)
        deviceAuth.attach(flutterEngine)
        localBackup.attach(flutterEngine)
        localShareNet.attach(flutterEngine)
        historySync.attach(flutterEngine)
        localShareFolder.attach(flutterEngine)
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
        // The media-send flow and the chat-lock confirm screen answer their
        // own MethodChannel calls; anything else belongs to a Flutter plugin
        // and must keep going to super.
        if (mediaSend.onActivityResult(requestCode, resultCode, data)) return
        if (deviceAuth.onActivityResult(requestCode, resultCode)) return
        if (localBackup.onActivityResult(requestCode, resultCode, data)) return
        if (localShareFolder.onActivityResult(requestCode, resultCode, data)) return
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

    /** A cheek at the ear must not press the call screen — see [ProximityTouchGuard]. */
    override fun dispatchTouchEvent(ev: MotionEvent): Boolean =
        callScreenLock.dispatchTouch(ev) { super.dispatchTouchEvent(it) }

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

    /**
     * Back on the app's home screen sends the app to the background instead of
     * finishing this Activity. Finishing destroys the FlutterEngine, and a
     * live call's WebRTC session lives in it — two presses of Back used to
     * hang up on the other person.
     */
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    override fun onDestroy() {
        // The in-app call screen died with the Activity; CallKit's own hold is
        // untouched, so a call ringing natively keeps ringing.
        CallRinger.release(FLUTTER_HOLDER)
        // A live call outlives this Activity: its WebRTC session is in the
        // FlutterEngine, and the engine is parked until the next MainActivity
        // (or until the call ends). Swiping the app out of Recents, or the OS
        // reclaiming the Activity, used to hang up on the other person.
        val engine = flutterEngine
        keepEngine = engine != null && OngoingCallService.running
        if (engine != null && keepEngine) CallEngineKeeper.keep(engine)
        if (!keepEngine) {
            // No call to carry, so the engine dies here. A service left
            // behind would show "Ongoing call" with nothing behind it.
            OngoingCallService.stop(this)
            ongoingCall.dispose()
        }
        shareIntake.dispose()
        pip.dispose()
        // Releases the proximity lock: a wake lock outliving the Activity would
        // keep the panel dark with no call left to justify it.
        callScreenLock.dispose()
        callRingback.dispose()
        if (!keepEngine) {
            // The engine dies with this Activity; give the phone its audio
            // mode back, as LiveKit's session did when its plugin detached.
            CallAudioSession.stop()
            CallAudioSession.detach()
        }
        callLockScreen.dispose()
        mediaGallery.dispose()
        mediaSend.dispose()
        appIcon.dispose()
        chatStore.dispose()
        battery.dispose()
        networkState.dispose()
        callHaptics.dispose()
        super.onDestroy()
    }

    companion object {
        /** Ring holder for the in-app call screen — mirrors `ring_holders.dart`. */
        private const val FLUTTER_HOLDER = "flutter"
    }
}
