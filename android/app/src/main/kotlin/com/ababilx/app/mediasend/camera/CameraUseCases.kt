package com.ababilx.app.mediasend.camera

import androidx.camera.core.AspectRatio
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.VideoCapture
import androidx.camera.view.PreviewView

/**
 * The three CameraX use cases, built the way Signal builds them: all 16:9,
 * photo tuned for speed, video at HD (or the nearest the lens offers) and at
 * a bitrate high enough that no sent-quality tier is sourced from a starved
 * capture.
 */
object CameraUseCases {

    private const val VIDEO_BITRATE_BPS = 4_000_000

    fun preview(view: PreviewView): Preview = Preview.Builder()
        .setResolutionSelector(sixteenByNine())
        .build()
        .also { it.surfaceProvider = view.surfaceProvider }

    /** Seeded with [flash]: a fresh ImageCapture defaults to flash off. */
    fun photo(flash: CameraFlash, rotation: Int): ImageCapture = ImageCapture.Builder()
        .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
        .setResolutionSelector(sixteenByNine())
        .setFlashMode(flash.cameraxMode)
        .setTargetRotation(rotation)
        .build()

    fun video(rotation: Int): VideoCapture<Recorder> {
        val recorder = Recorder.Builder()
            .setAspectRatio(AspectRatio.RATIO_16_9)
            .setQualitySelector(
                QualitySelector.from(Quality.HD, FallbackStrategy.lowerQualityOrHigherThan(Quality.HD)),
            )
            .setTargetVideoEncodingBitRate(VIDEO_BITRATE_BPS)
            .build()
        return VideoCapture.Builder(recorder).setTargetRotation(rotation).build()
    }

    private fun sixteenByNine() = ResolutionSelector.Builder()
        .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
        .build()
}
