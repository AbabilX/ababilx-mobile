package com.ababilx.app

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * One frame of a local video, written to the cache as a JPEG.
 *
 * The chat timeline used to draw every video bubble with its own live
 * `VideoPlayerController`, paused on the first frame. Each of those holds a
 * MediaCodec decoder, and a device has a small global pool of them — scroll
 * past a handful of videos and the pool is gone, which is black tiles here and
 * broken playback in whatever other app asks next. A poster frame costs one
 * decode and then draws as a plain bitmap.
 *
 * The duration and the frame's size ride in the cache file's *name*, so a hit
 * answers without opening the video a second time. Name shape:
 * `<stamp>.<durationMs>.<width>x<height>.jpg`.
 */
object VideoThumbnails {

    private const val TAG = "VideoThumbs"
    private const val DIR = "videothumbs"
    private const val QUALITY = 85

    fun of(context: Context, path: String, maxPx: Int): Map<String, Any>? {
        val source = File(path)
        if (!source.exists() || source.length() == 0L) return null
        val dir = File(context.cacheDir, DIR).apply { mkdirs() }
        val stamp = stampFor(source)
        cached(dir, stamp)?.let { return it }
        return extract(source, dir, stamp, max(maxPx, 64))
    }

    private fun extract(source: File, dir: File, stamp: String, maxPx: Int): Map<String, Any>? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(source.absolutePath)
            val durationMs = meta(retriever, MediaMetadataRetriever.METADATA_KEY_DURATION) ?: 0
            val frame = frame(retriever, maxPx) ?: return null
            val target = File(dir, "$stamp.$durationMs.${frame.width}x${frame.height}.jpg")
            FileOutputStream(target).use { frame.compress(Bitmap.CompressFormat.JPEG, QUALITY, it) }
            frame.recycle()
            if (target.length() > 0) describe(target) else null
        } catch (error: Exception) {
            Log.w(TAG, "thumbnail failed for ${source.name}", error)
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // The frame either arrived or it did not; nothing to do here.
            }
        }
    }

    /**
     * Scaled during extraction where the platform can do it (API 27+), which
     * keeps a 4K frame from ever becoming a full-size bitmap in memory.
     */
    private fun frame(retriever: MediaMetadataRetriever, maxPx: Int): Bitmap? {
        val rotation = meta(retriever, MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
        val rawWidth = meta(retriever, MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
        val rawHeight = meta(retriever, MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
        // A portrait video is stored landscape plus a 90° rotation flag, and
        // the retriever hands back the *rotated* frame — so the target size
        // has to be swapped too or the frame comes out squashed.
        val upright = rotation == 90 || rotation == 270
        val width = if (upright) rawHeight else rawWidth
        val height = if (upright) rawWidth else rawHeight

        if (Build.VERSION.SDK_INT >= 27 && width > 0 && height > 0) {
            val (targetWidth, targetHeight) = fit(width, height, maxPx)
            retriever.getScaledFrameAtTime(
                0,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                targetWidth,
                targetHeight,
            )?.let { return it }
        }
        val full = retriever.frameAtTime ?: return null
        return downscale(full, maxPx)
    }

    private fun downscale(bitmap: Bitmap, maxPx: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= maxPx || longest == 0) return bitmap
        val (width, height) = fit(bitmap.width, bitmap.height, maxPx)
        val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
        if (scaled != bitmap) bitmap.recycle()
        return scaled
    }

    private fun fit(width: Int, height: Int, maxPx: Int): Pair<Int, Int> {
        val longest = max(width, height)
        if (longest <= maxPx) return width to height
        val scale = maxPx.toFloat() / longest
        return max(1, (width * scale).roundToInt()) to max(1, (height * scale).roundToInt())
    }

    private fun meta(retriever: MediaMetadataRetriever, key: Int): Long? =
        retriever.extractMetadata(key)?.toLongOrNull()

    /** Identity of the bytes, not just the path: a re-download must re-decode. */
    private fun stampFor(source: File): String {
        val raw = "${source.absolutePath}:${source.length()}:${source.lastModified()}"
        return MessageDigest.getInstance("SHA-1")
            .digest(raw.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    private fun cached(dir: File, stamp: String): Map<String, Any>? {
        val hit = dir.listFiles { file -> file.name.startsWith("$stamp.") }?.firstOrNull()
        return hit?.let { describe(it) }
    }

    private fun describe(file: File): Map<String, Any>? {
        val parts = file.name.split('.')
        if (parts.size < 4) return null
        val durationMs = parts[1].toLongOrNull() ?: return null
        val size = parts[2].split('x')
        return mapOf(
            "path" to file.absolutePath,
            "durationMs" to durationMs,
            "width" to (size.getOrNull(0)?.toIntOrNull() ?: 0),
            "height" to (size.getOrNull(1)?.toIntOrNull() ?: 0),
        )
    }
}
