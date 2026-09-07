package com.ababilx.app.mediasend

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.util.Size

/**
 * MediaStore's own thumbnail, which is the difference between a grid that
 * fills as you scroll and one that stutters.
 *
 * Decoding a 12 MP JPEG down to a 360 px cell costs three `openInputStream`
 * calls (bounds, pixels, EXIF) and tens of milliseconds of CPU per photo —
 * paid again for every cell, on every album. `loadThumbnail` hands back the
 * thumbnail MediaProvider already generated and cached for the system gallery,
 * upright, in a fraction of that. A video costs a frame extraction the old way
 * and nothing at all this way, which is the bigger win of the two.
 *
 * Only for small targets. Asked for a large size the provider falls back to
 * decoding the original anyway — sometimes upscaling a 512 px thumbnail to get
 * there — so the review pager and the editor, which need real pixels to draw
 * strokes onto, keep the full decode in [MediaBitmaps].
 *
 * Returns null for anything that is not a MediaStore URI (a `file://` share, a
 * SAF document), and the caller decodes it the long way.
 */
object FastThumbnail {

    /** Above this the provider stops being a shortcut. Cells are ~360 px. */
    const val MAX_PX = 512

    fun of(context: Context, uri: Uri, sizePx: Int): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        if (sizePx <= 0 || sizePx > MAX_PX) return null
        return try {
            context.contentResolver.loadThumbnail(uri, Size(sizePx, sizePx), null)
        } catch (_: Exception) {
            null
        } catch (_: OutOfMemoryError) {
            null
        }
    }
}
