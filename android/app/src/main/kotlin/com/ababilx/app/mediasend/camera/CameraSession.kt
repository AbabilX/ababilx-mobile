package com.ababilx.app.mediasend.camera

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.core.ZoomState
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.Recorder
import androidx.camera.video.VideoCapture
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer

/**
 * The CameraX half of the camera screen: what is bound, to which lens, at
 * what zoom and flash. Signal's `CameraScreenViewModel` mechanism, written for
 * our View-based screen.
 *
 * - **Everything is 16:9**, preview and capture alike, so the photo that
 *   arrives in the review screen is the frame the viewfinder showed.
 * - **Binding falls back.** Preview + photo + video first; a device that
 *   cannot run all three at once gets preview + photo, and [ensureVideo]
 *   swaps photo for video only while a recording runs, then [restorePhoto]
 *   puts the photo use case back.
 * - **A failed bind is retried** three times, 500 ms apart: some HALs report
 *   no cameras until the previous session's resources are released.
 * - A fresh ImageCapture defaults to flash off, so every rebuild is seeded
 *   from [flash] — or the button would keep saying "on" while nothing fires.
 */
class CameraSession(
    private val context: Context,
    private val owner: CameraLifecycle,
    private val previewView: PreviewView,
    private val onZoom: (ratio: Float, range: ClosedFloatingPointRange<Float>) -> Unit,
    private val onBound: (hasFront: Boolean, hasFlash: Boolean) -> Unit,
    private val onFailed: () -> Unit,
) {

    var lensFacing = CameraSelector.LENS_FACING_BACK
        private set
    var flash = CameraFlash.OFF
        private set
    var imageCapture: ImageCapture? = null
        private set
    var videoCapture: VideoCapture<Recorder>? = null
        private set

    var currentZoom = 1f
        private set

    val isFront: Boolean get() = lensFacing == CameraSelector.LENS_FACING_FRONT

    private val main = Handler(Looper.getMainLooper())
    private var provider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var targetRotation = Surface.ROTATION_0
    private val zoomObserver = Observer<ZoomState> { state ->
        currentZoom = state.zoomRatio
        onZoom(state.zoomRatio, state.minZoomRatio..state.maxZoomRatio)
    }

    fun start() {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            provider = runCatching { future.get() }.getOrNull()
            if (provider == null) onFailed() else bindWithRetry(0)
        }, ContextCompat.getMainExecutor(context))
    }

    fun flip() {
        lensFacing = if (isFront) CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
        bindWithRetry(0)
    }

    fun setFlash(value: CameraFlash) {
        flash = value
        imageCapture?.flashMode = value.cameraxMode
    }

    /** Capture always follows the phone's real rotation, so photos are upright. */
    fun setTargetRotation(rotation: Int) {
        targetRotation = rotation
        imageCapture?.targetRotation = rotation
        videoCapture?.targetRotation = rotation
    }

    fun setZoomRatio(ratio: Float) {
        camera?.cameraControl?.setZoomRatio(ratio)
    }

    fun pinch(factor: Float) {
        val state = camera?.cameraInfo?.zoomState?.value ?: return
        setZoomRatio((currentZoom * factor).coerceIn(state.minZoomRatio, state.maxZoomRatio))
    }

    /** A drag along the held capture button; see [ZoomMath.dragTarget]. */
    fun dragZoom(base: Float, linear: Float) {
        val state = camera?.cameraInfo?.zoomState?.value ?: return
        setZoomRatio(ZoomMath.dragTarget(base, linear, state.minZoomRatio, state.maxZoomRatio))
    }

    fun focus(x: Float, y: Float) {
        val point = previewView.meteringPointFactory.createPoint(x, y)
        camera?.cameraControl?.startFocusAndMetering(FocusMeteringAction.Builder(point).build())
    }

    fun torch(on: Boolean) {
        camera?.cameraControl?.enableTorch(on)
    }

    /**
     * The video use case, binding it in place of photo on a device that could
     * not hold both. Null when even that fails.
     */
    fun ensureVideo(): VideoCapture<Recorder>? {
        videoCapture?.let { return it }
        val video = CameraUseCases.video(targetRotation)
        return if (bind(listOfNotNull(preview, video))) {
            videoCapture = video
            imageCapture = null
            video
        } else {
            restorePhoto()
            null
        }
    }

    /** After a recording on a limited device: preview + photo again. */
    fun restorePhoto() {
        if (imageCapture != null) return
        bindWithRetry(0)
    }

    fun release() {
        camera?.cameraInfo?.zoomState?.removeObserver(zoomObserver)
        runCatching { provider?.unbindAll() }
        camera = null
    }

    private fun bindWithRetry(attempt: Int) {
        if (tryBind()) return
        if (attempt >= MAX_RETRIES) {
            Log.e(TAG, "camera bind failed after retries")
            onFailed()
            return
        }
        main.postDelayed({ bindWithRetry(attempt + 1) }, RETRY_DELAY_MS)
    }

    private fun tryBind(): Boolean {
        val newPreview = CameraUseCases.preview(previewView)
        val photo = CameraUseCases.photo(flash, targetRotation)
        val video = CameraUseCases.video(targetRotation)
        for (useCases in listOf(listOf(newPreview, photo, video), listOf(newPreview, photo))) {
            if (bind(useCases)) {
                preview = newPreview
                imageCapture = photo
                videoCapture = if (useCases.contains(video)) video else null
                return true
            }
        }
        return false
    }

    private fun bind(useCases: List<UseCase>): Boolean {
        val provider = provider ?: return false
        val selector = CameraSelector.Builder().requireLensFacing(lensFacing).build()
        return try {
            camera?.cameraInfo?.zoomState?.removeObserver(zoomObserver)
            provider.unbindAll()
            val bound = provider.bindToLifecycle(owner, selector, *useCases.toTypedArray())
            camera = bound
            bound.cameraInfo.zoomState.observe(owner, zoomObserver)
            val hasFront = runCatching {
                provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) &&
                    provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)
            }.getOrDefault(false)
            onBound(hasFront, bound.cameraInfo.hasFlashUnit())
            true
        } catch (error: Exception) {
            Log.w(TAG, "bind ${useCases.size} use cases failed", error)
            false
        }
    }

    private companion object {
        const val TAG = "CameraSession"
        const val MAX_RETRIES = 3
        const val RETRY_DELAY_MS = 500L
    }
}
