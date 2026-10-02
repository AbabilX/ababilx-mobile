package com.ababilx.app.mediasend.camera

import android.app.Activity
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import com.ababilx.app.MediaGalleryQuery
import com.ababilx.app.R
import com.ababilx.app.mediasend.MediaSendPermissions
import com.ababilx.app.mediasend.ThumbnailLoader
import java.util.Locale
import java.util.concurrent.Executor

/**
 * What the camera's controls show and what pressing them asks for — Signal's
 * StandardCameraHud rules, on Views:
 *
 * - while recording, the flash, gallery and switch go away, the close button
 *   stays (and does nothing until the take ends), and a red timer pill sits
 *   between the top corners;
 * - Photo mode: tap = photo, hold = a recording that lasts as long as the
 *   finger, and sliding that finger up zooms in (down zooms back out);
 * - Video mode: tap starts a recording that runs unheld, tap again stops it;
 * - the gallery corner shows the newest photo in the library, Signal's way of
 *   saying "the rest of your pictures are here".
 */
class CameraHud(private val root: View) {

    var onClose: () -> Unit = {}
    var onGallery: () -> Unit = {}
    var onFlip: () -> Unit = {}
    var onFlash: () -> Unit = {}
    var onZoomLevel: (Float) -> Unit = {}
    var onPhoto: () -> Unit = {}
    var onStartRecording: () -> Boolean = { false }
    var onStopRecording: () -> Unit = {}
    var onHoldZoom: (base: Float, linear: Float) -> Unit = { _, _ -> }
    var currentZoom: () -> Float = { 1f }

    var allowVideo = true
        set(value) {
            field = value
            capture.holdToRecord = value
        }

    var mode = CaptureMode.PHOTO
        set(value) {
            field = value
            if (!recording) capture.state = idleState()
        }

    private val main = Handler(Looper.getMainLooper())
    private val close: ImageButton = root.findViewById(R.id.camera_close)
    private val flash: ImageButton = root.findViewById(R.id.camera_flash)
    private val flip: ImageButton = root.findViewById(R.id.camera_flip)
    private val gallery: View = root.findViewById(R.id.camera_gallery)
    private val galleryIcon: ImageView = root.findViewById(R.id.camera_gallery_icon)
    private val galleryThumb: ImageView = root.findViewById(R.id.camera_gallery_thumb)
    private val timer: TextView = root.findViewById(R.id.camera_timer)
    private val zoom: ZoomBar = root.findViewById(R.id.camera_zoom)
    private val capture: CaptureButton = root.findViewById(R.id.camera_capture)

    private var recording = false
    private var hasFront = false
    private var hasFlash = false
    private var holdBase = 1f

    init {
        galleryThumb.outlineProvider = ViewOutlineProvider.BACKGROUND
        galleryThumb.setBackgroundResource(R.drawable.ms_camera_control)
        galleryThumb.clipToOutline = true
        close.setOnClickListener { onClose() }
        flash.setOnClickListener { onFlash() }
        flip.setOnClickListener { onFlip() }
        gallery.setOnClickListener { onGallery() }
        zoom.onLevel = { onZoomLevel(it) }
        capture.onTap = ::tap
        capture.onHoldStart = {
            holdBase = currentZoom()
            if (onStartRecording()) capture.state = CaptureButton.State.RECORDING_HELD
            else capture.state = idleState()
        }
        capture.onHoldEnd = { if (recording) onStopRecording() else capture.state = idleState() }
        capture.onHoldDrag = { dy ->
            onHoldZoom(holdBase, -dy * DRAG_MULTIPLIER / root.height.coerceAtLeast(1))
        }
    }

    private fun tap() {
        when (capture.state) {
            CaptureButton.State.PHOTO -> onPhoto()
            CaptureButton.State.VIDEO ->
                if (onStartRecording()) capture.state = CaptureButton.State.RECORDING_LOCKED
            CaptureButton.State.RECORDING_LOCKED -> onStopRecording()
            CaptureButton.State.RECORDING_HELD -> Unit
        }
    }

    private fun idleState() =
        if (mode == CaptureMode.VIDEO) CaptureButton.State.VIDEO else CaptureButton.State.PHOTO

    /** Fresh on every visit: nothing from the last take carries over. */
    fun reset() {
        recording = false
        capture.state = idleState()
        showRecording(false)
    }

    fun showBound(hasFront: Boolean, hasFlash: Boolean, current: CameraFlash?) {
        this.hasFront = hasFront
        this.hasFlash = hasFlash
        current?.let(::showFlash)
        applyChrome()
    }

    fun showFlash(value: CameraFlash) {
        flash.setImageResource(value.icon)
        flash.contentDescription = root.context.getString(value.label)
    }

    fun showZoom(ratio: Float, range: ClosedFloatingPointRange<Float>) = zoom.update(ratio, range)

    fun showRecording(value: Boolean) {
        recording = value
        if (value) {
            timer.text = format(0)
        } else {
            capture.state = idleState()
        }
        timer.visibility = if (value) View.VISIBLE else View.GONE
        applyChrome()
    }

    fun showElapsed(ms: Long) {
        timer.text = format(ms)
    }

    fun spinFlip() {
        flip.animate().rotationBy(180f).setDuration(FLIP_SPIN_MS).start()
    }

    fun rotateIcons(degrees: Float) {
        for (view in listOf(close, flash, galleryIcon, galleryThumb)) {
            view.animate().rotation(degrees).setDuration(ROTATE_MS).start()
        }
        zoom.rotateLabels(degrees)
    }

    fun loadGalleryThumb(loader: ThumbnailLoader?, io: Executor?) {
        val activity = root.context as Activity
        if (loader == null || io == null || !MediaSendPermissions.granted(activity)) return showThumb(null)
        io.execute {
            val kind = if (allowVideo) "all" else "image"
            val newest = MediaGalleryQuery.page(activity, 0, 1, kind).firstOrNull()
            val uri = (newest?.get("uri") as? String)?.let(Uri::parse)
            val isVideo = newest?.get("isVideo") as? Boolean ?: false
            main.post {
                showThumb(uri)
                if (uri != null) loader.load(galleryThumb, uri, isVideo, thumbPx())
            }
        }
    }

    private fun showThumb(uri: Uri?) {
        galleryThumb.visibility = if (uri != null) View.VISIBLE else View.GONE
        galleryIcon.visibility = if (uri != null) View.GONE else View.VISIBLE
    }

    private fun applyChrome() {
        flash.visibility = if (!recording && hasFlash) View.VISIBLE else View.GONE
        flip.visibility = if (!recording && hasFront) View.VISIBLE else View.INVISIBLE
        gallery.visibility = if (recording) View.INVISIBLE else View.VISIBLE
        close.alpha = if (recording) DIMMED else 1f
    }

    private fun thumbPx() = (THUMB_DP * root.resources.displayMetrics.density).toInt()

    private fun format(ms: Long): String {
        val seconds = ms / 1000
        return String.format(Locale.US, "%02d:%02d", seconds / 60, seconds % 60)
    }

    private companion object {
        /** Signal's: a third of the screen's height takes the lens to its limit. */
        const val DRAG_MULTIPLIER = 3f
        const val THUMB_DP = 44f
        const val DIMMED = 0.4f
        const val ROTATE_MS = 200L
        const val FLIP_SPIN_MS = 300L
    }
}
