package com.ababilx.app.mediasend.camera

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.net.Uri
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.Toast
import androidx.camera.view.PreviewView
import com.ababilx.app.R
import com.ababilx.app.mediasend.PickedItem
import com.ababilx.app.mediasend.ThumbnailLoader
import java.io.File
import java.util.concurrent.Executor

/**
 * Signal's in-app camera, replacing the hand-off to the phone's own camera
 * app: a rounded 9:16 viewfinder card with close and flash on top, the zoom
 * bar, then gallery · capture · switch, and the Video | Photo bar beneath.
 *
 * [CameraSession] owns CameraX, [CameraShots] the capture, [CameraHud] the
 * controls. The device is open only while this screen is shown and the app
 * is in front ([CameraLifecycle]); the Activity is held portrait meanwhile
 * and the icons turn instead ([DeviceRotation]), as Signal does on a phone.
 */
class CameraView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    var onClose: () -> Unit = {}
    var onGallery: () -> Unit = {}
    var onCaptured: (PickedItem) -> Unit = {}

    /** CameraX could not open any camera; the caller falls back to the camera app. */
    var onUnavailable: () -> Unit = {}

    private val activity = context as Activity
    private val lifecycle = CameraLifecycle()
    private val card: FrameLayout
    private val preview: PreviewView
    private val modes: CaptureModeBar
    private val hud: CameraHud
    private var session: CameraSession? = null
    private var shots: CameraShots? = null
    private var io: Executor? = null
    private var loader: ThumbnailLoader? = null
    private var everBound = false
    private var restoreOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    private val rotation = DeviceRotation(context) { surfaceRotation, iconDegrees ->
        session?.setTargetRotation(surfaceRotation)
        hud.rotateIcons(iconDegrees)
    }

    var allowVideo = true
        set(value) {
            field = value
            modes.visibility = if (value) VISIBLE else GONE
            hud.allowVideo = value
        }

    init {
        setBackgroundResource(R.color.media_send_bg)
        LayoutInflater.from(context).inflate(R.layout.media_send_camera, this, true)
        card = findViewById(R.id.camera_card)
        card.outlineProvider = ViewOutlineProvider.BACKGROUND
        card.clipToOutline = true
        preview = findViewById(R.id.camera_preview)
        // A TextureView, so the card's rounded outline clips the picture.
        preview.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        preview.scaleType = PreviewView.ScaleType.FILL_CENTER
        modes = findViewById(R.id.camera_modes)
        hud = CameraHud(this)
        hud.onClose = { if (shots?.isRecording != true) onClose() }
        hud.onGallery = { onGallery() }
        hud.onFlip = ::flip
        hud.onFlash = { session?.let { it.setFlash(it.flash.next()); hud.showFlash(it.flash) } }
        hud.onZoomLevel = { session?.setZoomRatio(it) }
        hud.onPhoto = { shots?.photo() }
        hud.onStartRecording = { shots?.startRecording() ?: false }
        hud.onStopRecording = { shots?.stopRecording() }
        hud.onHoldZoom = { base, linear -> session?.dragZoom(base, linear) }
        hud.currentZoom = { session?.currentZoom ?: 1f }
        modes.onMode = { hud.mode = it }
        modes.select(CaptureMode.PHOTO)
        ViewfinderGestures(preview, findViewById(R.id.camera_focus_ring), { session }, ::flip).install()

        CameraCardLayout.install(
            root = this,
            card = card,
            modes = modes,
            controls = findViewById(R.id.camera_controls),
            zoom = findViewById(R.id.camera_zoom),
        )
    }

    fun attach(loader: ThumbnailLoader, io: Executor) {
        this.loader = loader
        this.io = io
    }

    /** The navigator just put this screen up. */
    fun show() {
        restoreOrientation = activity.requestedOrientation
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        lifecycle.setShown(true)
        rotation.start()
        if (session == null) start()
        hud.reset()
        hud.loadGalleryThumb(loader, io)
    }

    /** Another screen replaced this one. A running take is stopped, not lost. */
    fun hide() {
        shots?.takeIf { it.isRecording }?.stopRecording()
        rotation.stop()
        lifecycle.setShown(false)
        activity.requestedOrientation = restoreOrientation
    }

    fun setForeground(value: Boolean) {
        if (!value) shots?.takeIf { it.isRecording }?.stopRecording()
        lifecycle.setForeground(value)
    }

    /** Back while recording stops the take; otherwise it is the caller's. */
    fun handleBack(): Boolean =
        shots?.takeIf { it.isRecording }?.also { it.stopRecording() } != null

    fun dispose() {
        rotation.stop()
        session?.release()
        lifecycle.destroy()
    }

    private fun start() {
        val io = io ?: return
        val created = CameraSession(
            context = context,
            owner = lifecycle,
            previewView = preview,
            onZoom = hud::showZoom,
            onBound = { hasFront, hasFlash ->
                everBound = true
                // The front lens has no flash but "On" lights the screen instead.
                hud.showBound(hasFront, hasFlash || session?.isFront == true, session?.flash)
            },
            // Only a camera that never opened is "unavailable"; a lens switch
            // that fails later must not throw the user into another app.
            onFailed = { if (everBound) toast(R.string.media_send_photo_failed) else onUnavailable() },
        )
        session = created
        shots = CameraShots(
            activity = activity,
            session = created,
            io = io,
            shutter = findViewById(R.id.camera_shutter),
            selfieFlash = findViewById(R.id.camera_selfie_flash),
            onPhoto = { deliver(it, "image/jpeg", isVideo = false) },
            onVideo = { deliver(it, "video/mp4", isVideo = true) },
            onRecording = { recording ->
                hud.showRecording(recording)
                modes.visibility = if (recording || !allowVideo) INVISIBLE else VISIBLE
            },
            onTick = hud::showElapsed,
            onFailed = ::toast,
        )
        created.setTargetRotation(rotation.rotation)
        created.start()
    }

    private fun flip() {
        if (shots?.isRecording == true) return
        session?.flip()
        hud.spinFlip()
    }

    private fun toast(res: Int) = Toast.makeText(context, res, Toast.LENGTH_SHORT).show()

    private fun deliver(file: File, mime: String, isVideo: Boolean) {
        onCaptured(PickedItem(Uri.fromFile(file), file.name, mime, isVideo, file.length()))
    }
}
