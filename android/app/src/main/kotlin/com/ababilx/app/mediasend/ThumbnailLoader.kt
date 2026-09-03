package com.ababilx.app.mediasend

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.widget.ImageView
import com.ababilx.app.R
import java.util.concurrent.Executors

/**
 * The grid's image pipeline, in about eighty lines.
 *
 * A cell is recycled long before its decode finishes, so every request stamps
 * the target with the URI it is for and the result is dropped unless the tag
 * still matches — the classic wrong-photo-in-the-wrong-cell bug. Cache is a
 * quarter of the heap, which is what Glide would take anyway.
 */
class ThumbnailLoader(private val context: Context) {

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newFixedThreadPool(THREADS)
    private val cache = object : LruCache<String, Bitmap>(
        (Runtime.getRuntime().maxMemory() / 1024 / 4).toInt().coerceAtLeast(4096),
    ) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount / 1024
    }

    fun load(target: ImageView, uri: Uri, isVideo: Boolean, sizePx: Int) {
        val key = "$uri@$sizePx"
        target.setTag(R.id.media_send_thumb_key, key)
        cache.get(key)?.let {
            target.setImageBitmap(it)
            return
        }
        target.setImageDrawable(null)
        io.execute {
            val bitmap = MediaBitmaps.preview(context, uri, isVideo, sizePx) ?: return@execute
            val scaled = scale(bitmap, sizePx)
            cache.put(key, scaled)
            main.post {
                if (target.getTag(R.id.media_send_thumb_key) == key) target.setImageBitmap(scaled)
            }
        }
    }

    /**
     * The same cache, but handing back the bitmap itself — the review pager
     * and the editor draw onto a canvas rather than into an ImageView, and
     * must not decode the same photo a second time to do it.
     */
    fun bitmap(uri: Uri, isVideo: Boolean, sizePx: Int, onReady: (Bitmap) -> Unit) {
        val key = "$uri@$sizePx"
        cache.get(key)?.let {
            onReady(it)
            return
        }
        io.execute {
            val decoded = MediaBitmaps.preview(context, uri, isVideo, sizePx) ?: return@execute
            val scaled = scale(decoded, sizePx)
            cache.put(key, scaled)
            main.post { onReady(scaled) }
        }
    }

    fun dispose() {
        io.shutdownNow()
        cache.evictAll()
    }

    /** Square-ish downscale so the cache holds cells, not originals. */
    private fun scale(source: Bitmap, sizePx: Int): Bitmap {
        val longest = maxOf(source.width, source.height)
        if (longest <= sizePx) return source
        val factor = sizePx.toFloat() / longest
        val out = Bitmap.createScaledBitmap(
            source,
            (source.width * factor).toInt().coerceAtLeast(1),
            (source.height * factor).toInt().coerceAtLeast(1),
            true,
        )
        if (out != source) source.recycle()
        return out
    }

    private companion object {
        const val THREADS = 4
    }
}
