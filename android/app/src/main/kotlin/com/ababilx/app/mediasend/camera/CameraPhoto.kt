package com.ababilx.app.mediasend.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import com.ababilx.app.mediasend.MediaSendExport
import java.io.File
import java.util.concurrent.Executor

/**
 * Takes one photo into the flow's cache folder.
 *
 * **A selfie is mirrored, the way the viewfinder drew it** — Signal flips the
 * front camera's frame so the picture is the one the person was looking at.
 * CameraX can only record that as an EXIF flip, which the rest of the flow
 * (it reads rotation, not flips) would quietly drop, so the file is
 * re-encoded upright and mirrored instead, off the main thread.
 */
class CameraPhoto(
    private val context: Context,
    private val io: Executor,
) {

    private val main = Handler(Looper.getMainLooper())

    fun take(capture: ImageCapture, mirror: Boolean, onDone: (File?) -> Unit) {
        val file = MediaSendExport.cacheFile(context, "photo-${System.currentTimeMillis()}.jpg")
        val options = ImageCapture.OutputFileOptions.Builder(file).build()
        capture.takePicture(
            options,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    if (!mirror) {
                        onDone(file.takeIf { it.length() > 0 })
                        return
                    }
                    io.execute {
                        val ok = mirrorInPlace(file)
                        main.post { onDone(file.takeIf { ok && it.length() > 0 }) }
                    }
                }

                override fun onError(error: ImageCaptureException) {
                    Log.w(TAG, "photo capture failed", error)
                    onDone(null)
                }
            },
        )
    }

    private fun mirrorInPlace(file: File): Boolean = try {
        val degrees = when (
            ExifInterface(file).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val source = BitmapFactory.decodeFile(file.absolutePath)
        if (source == null) {
            false
        } else {
            val matrix = Matrix().apply {
                postRotate(degrees)
                postScale(-1f, 1f)
            }
            val upright = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
            if (upright != source) source.recycle()
            // Written beside and renamed over, so a failure halfway leaves the
            // original shot intact rather than a truncated file.
            val temp = File(file.parentFile, "${file.name}.mirror")
            temp.outputStream().use { upright.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it) }
            upright.recycle()
            temp.renameTo(file) || run { temp.delete(); true }
        }
    } catch (error: Throwable) {
        // An unmirrored selfie is still the photo; keep it rather than lose it.
        Log.w(TAG, "mirror failed, keeping the original", error)
        true
    }

    private companion object {
        const val TAG = "CameraPhoto"
        const val JPEG_QUALITY = 95
    }
}
