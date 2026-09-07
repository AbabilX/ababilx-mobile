package com.ababilx.app.mediasend

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.ImageView
import com.ababilx.app.R
import java.util.concurrent.Executors
import java.util.concurrent.Future

/**
 * The grid's image pipeline: one decode per photo per size, at most once, and
 * only while something still wants it.
 *
 * Three rules, each of which came from a real symptom:
 *
 * - **A cell is recycled long before its decode finishes**, so every request
 *   stamps its target with the key it is for and the result is dropped unless
 *   the tag still matches — the classic wrong-photo-in-the-wrong-cell bug.
 * - **A fling must not pay for every cell it passed.** Re-binding a target
 *   releases its old request, and a request nothing is waiting for any more is
 *   cancelled before it reaches the pool. The tag check alone only discarded
 *   the *result*, after the decode had already run.
 * - **Two screens asking for the same photo at the same time share one
 *   decode.** The review pager and its rail bind together, and without the
 *   in-flight table that was two full decodes of the same picture.
 *
 * All bookkeeping happens on the main thread, which is where every entry point
 * is called from; only the decode itself runs on the pool.
 */
class ThumbnailLoader(private val context: Context) {

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newFixedThreadPool(THREADS)
    private val cache = ThumbnailCache()
    private val inFlight = HashMap<String, Pending>()

    private class Pending {
        val waiters = mutableListOf<(Bitmap) -> Unit>()
        var future: Future<*>? = null
    }

    /** What one ImageView is currently waiting for, so it can let go. */
    private class Claim(val key: String, val waiter: (Bitmap) -> Unit)

    fun load(target: ImageView, uri: Uri, isVideo: Boolean, sizePx: Int) {
        release(target)
        val key = key(uri, sizePx)
        target.setTag(R.id.media_send_thumb_key, key)
        cache.get(uri, sizePx)?.let {
            target.setImageBitmap(it)
            return
        }
        target.setImageDrawable(null)
        val waiter: (Bitmap) -> Unit = { bitmap ->
            if (target.getTag(R.id.media_send_thumb_key) == key) target.setImageBitmap(bitmap)
        }
        target.setTag(R.id.media_send_thumb_claim, Claim(key, waiter))
        request(uri, isVideo, sizePx, waiter)
    }

    /**
     * The same cache, handing back the bitmap itself — the review pager and
     * the editor draw onto a canvas rather than into an ImageView, and must
     * not decode the same photo a second time to do it.
     */
    fun bitmap(uri: Uri, isVideo: Boolean, sizePx: Int, onReady: (Bitmap) -> Unit) {
        cache.get(uri, sizePx)?.let {
            onReady(it)
            return
        }
        request(uri, isVideo, sizePx, onReady)
    }

    fun dispose() {
        io.shutdownNow()
        inFlight.clear()
        cache.evictAll()
    }

    /** Stops this target waiting, and cancels the decode if nobody else is. */
    private fun release(target: ImageView) {
        val claim = target.getTag(R.id.media_send_thumb_claim) as? Claim ?: return
        target.setTag(R.id.media_send_thumb_claim, null)
        val pending = inFlight[claim.key] ?: return
        // The entry under this key may already be a LATER request — see the
        // identity check in [request]. Only the one this claim actually joined
        // may be cancelled.
        if (!pending.waiters.remove(claim.waiter)) return
        if (pending.waiters.isNotEmpty()) return
        inFlight.remove(claim.key)
        // false: a decode already running is left to finish and fill the
        // cache, since the work is spent either way and the next bind of that
        // photo will want it.
        pending.future?.cancel(false)
    }

    private fun request(uri: Uri, isVideo: Boolean, sizePx: Int, onReady: (Bitmap) -> Unit) {
        val key = key(uri, sizePx)
        inFlight[key]?.let {
            it.waiters.add(onReady)
            return
        }
        val pending = Pending().apply { waiters.add(onReady) }
        inFlight[key] = pending
        pending.future = io.submit {
            val decoded = MediaBitmaps.preview(context, uri, isVideo, sizePx)
            val bitmap = decoded?.let { exactly(it, sizePx) }
            main.post {
                // Identity, not just the key: a cancelled-but-already-running
                // decode finishes after its slot may have been claimed by a
                // fresh request for the same photo, and removing that one
                // would leave the next binder decoding it a third time.
                if (inFlight[key] === pending) inFlight.remove(key)
                if (bitmap == null) return@post
                cache.put(uri, sizePx, bitmap)
                for (waiter in pending.waiters) waiter(bitmap)
            }
        }
    }

    /**
     * `inSampleSize` only halves, and the provider's thumbnail is whatever
     * size it had, so a decode lands at up to twice the target — four times
     * the memory. The cache holds cells, not near-originals, so the last step
     * down is taken here, on the pool rather than the main thread.
     */
    private fun exactly(source: Bitmap, sizePx: Int): Bitmap {
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

    private fun key(uri: Uri, sizePx: Int) = "$uri@$sizePx"

    private companion object {
        const val THREADS = 4
    }
}
