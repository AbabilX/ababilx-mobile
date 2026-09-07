package com.ababilx.app.mediasend.gallery

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

/**
 * One album's worth of MediaStore, read a page at a time as the grid scrolls.
 *
 * Split out of [GalleryView] when the album list arrived: switching album is
 * "throw the rows away and start again at offset zero", and that is only safe
 * if the offset, the in-flight guard and the exhausted flag live in one place
 * that can be reset together. A page landing for the album the user just left
 * is dropped by its generation, not by luck.
 */
class GalleryPaging(
    private val context: Context,
    private val adapter: GalleryAdapter,
    private val allowVideo: Boolean,
    private val onChanged: (Int) -> Unit,
) {

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var bucketId: String? = null
    private var generation = 0
    private var loading = false
    private var exhausted = false

    /** Points at a different album and empties the grid. */
    fun open(bucket: String?) {
        generation += 1
        bucketId = bucket
        loading = false
        exhausted = false
        adapter.clear()
        onChanged(0)
        more()
    }

    fun more() {
        if (loading || exhausted) return
        loading = true
        val wanted = generation
        val offset = adapter.count
        val bucket = bucketId
        io.execute {
            val page = GalleryRepository.page(context, offset, allowVideo, bucket)
            main.post {
                // The user moved to another album while this page was in
                // flight; appending it now would mix two albums in one grid.
                if (wanted != generation) return@post
                loading = false
                if (page.size < GalleryRepository.PAGE) exhausted = true
                adapter.append(page)
                onChanged(adapter.count)
            }
        }
    }

    fun dispose() = io.shutdownNow()
}
