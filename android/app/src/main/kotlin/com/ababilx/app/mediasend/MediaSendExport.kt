package com.ababilx.app.mediasend

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import com.ababilx.app.mediasend.editor.EditRender
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Turns the review screen's model into files the Dart uploader can read.
 *
 * Two things decide what happens to an item: whether it was edited, and which
 * [MediaQuality] the review screen was sent at.
 *
 * A photo that already fits the chosen level is *copied*, never re-encoded —
 * sending an already-small picture must not cost a generation of JPEG quality.
 * Anything larger, and anything edited, is flattened once here at the first
 * size target that lands under the level's byte cap. A video is never decoded
 * at all: there is no transcoder in this flow, so quality does not reach it.
 */
object MediaSendExport {

    private const val TAG = "MediaSendExport"

    /** Concurrent encodes. See [exportAll] for why this is not core count. */
    private const val LANES = 2

    class Output(
        val path: String,
        val name: String,
        val mime: String,
        val sizeBytes: Long,
    )

    /**
     * Every item, in the order given, encoded on a small pool.
     *
     * Encoding is CPU-bound and independent per file, so an album of ten went
     * through one JPEG generation after another on the Activity's single
     * export thread — a few seconds of a frozen Send button with nothing on
     * screen to explain it.
     *
     * Two lanes, not one per core. Each lane holds a decoded bitmap at the
     * quality level's largest target, which on High is a 4096 px edge — about
     * 50 MB — and a phone that runs four of those at once trades the stall for
     * an out-of-memory. Order is kept because the results are collected from
     * the futures in submission order, not as they finish.
     */
    fun exportAll(
        context: Context,
        items: List<PickedItem>,
        quality: MediaQuality,
    ): List<Output> {
        if (items.size < 2) return items.mapNotNull { export(context, it, quality) }
        val pool = Executors.newFixedThreadPool(LANES)
        return try {
            items.map { item -> pool.submit<Output?> { export(context, item, quality) } }
                .mapNotNull { future -> runCatching { future.get() }.getOrNull() }
        } catch (error: Exception) {
            Log.w(TAG, "parallel export failed", error)
            items.mapNotNull { export(context, it, quality) }
        } finally {
            pool.shutdown()
        }
    }

    fun export(context: Context, item: PickedItem, quality: MediaQuality): Output? = when {
        item.isVideo -> copy(context, item)
        item.edited -> flatten(context, item, quality)
        needsShrinking(context, item, quality) -> flatten(context, item, quality)
        else -> copy(context, item)
    }

    /**
     * Whether an untouched picture is already inside the level's bounds. Read
     * from the bounds decode and the file length, so an image that passes costs
     * no full decode at all.
     */
    private fun needsShrinking(
        context: Context,
        item: PickedItem,
        quality: MediaQuality,
    ): Boolean = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(item.uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        }
        val longest = max(bounds.outWidth, bounds.outHeight)
        // A bounds decode that told us nothing is not evidence of a small
        // photo; shrink it and let the encoder decide.
        if (longest <= 0) true else longest > quality.largestTarget || sourceBytes(context, item) > quality.maxBytes
    } catch (_: Exception) {
        true
    }

    private fun sourceBytes(context: Context, item: PickedItem): Long {
        if (item.sizeBytes > 0) return item.sizeBytes
        return try {
            context.contentResolver.openAssetFileDescriptor(item.uri, "r")?.use { it.length }
                ?.takeIf { it > 0 } ?: Long.MAX_VALUE
        } catch (_: Exception) {
            Long.MAX_VALUE
        }
    }

    private fun flatten(context: Context, item: PickedItem, quality: MediaQuality): Output? = try {
        val source = MediaBitmaps.decode(context, item.uri, quality.largestTarget)
        if (source == null) {
            copy(context, item)
        } else {
            val rendered = if (item.edited) EditRender.export(source, item) else source
            val bytes = encodeToFit(rendered, quality)
            if (rendered !== source) rendered.recycle()
            source.recycle()
            if (bytes == null) {
                copy(context, item)
            } else {
                val name = jpegName(item.name)
                val target = cacheFile(context, name)
                target.outputStream().use { it.write(bytes) }
                Output(target.absolutePath, name, "image/jpeg", target.length())
            }
        }
    } catch (error: Exception) {
        Log.w(TAG, "flatten failed", error)
        copy(context, item)
    } catch (_: OutOfMemoryError) {
        copy(context, item)
    }

    /**
     * Signal's ladder: encode at each target longest side in turn and keep the
     * first result under the cap. The smallest target is returned even when it
     * misses, because a slightly oversized picture beats no picture.
     */
    private fun encodeToFit(bitmap: Bitmap, quality: MediaQuality): ByteArray? {
        var last: ByteArray? = null
        for (target in quality.sizeTargets) {
            val scaled = scaleTo(bitmap, target)
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, quality.jpegQuality, out)
            if (scaled !== bitmap) scaled.recycle()
            last = out.toByteArray()
            if (last.size <= quality.maxBytes) return last
        }
        return last
    }

    private fun scaleTo(bitmap: Bitmap, target: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= target) return bitmap
        val scale = target.toFloat() / longest
        val width = (bitmap.width * scale).roundToInt().coerceAtLeast(1)
        val height = (bitmap.height * scale).roundToInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    private fun copy(context: Context, item: PickedItem): Output? = try {
        val target = cacheFile(context, item.name)
        context.contentResolver.openInputStream(item.uri)?.use { input ->
            target.outputStream().use { input.copyTo(it) }
        }
        if (target.length() > 0) {
            Output(target.absolutePath, item.name, item.mime, target.length())
        } else {
            null
        }
    } catch (error: Exception) {
        Log.w(TAG, "copy failed", error)
        null
    }

    fun cacheFile(context: Context, name: String): File {
        val dir = File(context.cacheDir, "mediasend").apply { mkdirs() }
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_").takeLast(80)
        return File(dir, "${System.currentTimeMillis()}-$safe")
    }

    /** A re-encoded picture is always a JPEG, whatever the original was. */
    private fun jpegName(name: String): String {
        val base = name.substringBeforeLast('.', name)
        return "$base.jpg"
    }

    fun displayName(context: Context, uri: Uri, fallback: String): String = try {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) ?: fallback else fallback
        } ?: fallback
    } catch (_: Exception) {
        fallback
    }
}
