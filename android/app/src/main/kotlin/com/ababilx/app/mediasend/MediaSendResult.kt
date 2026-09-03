package com.ababilx.app.mediasend

import android.content.Intent

/**
 * The one shape the flow reports back in: parallel arrays of exported files
 * plus the single message typed under the album.
 *
 * Parallel arrays rather than a Parcelable list because the other end is Dart:
 * primitive extras cross the MethodChannel without a codec of their own.
 */
object MediaSendResult {

    const val PATHS = "paths"
    const val NAMES = "names"
    const val MIMES = "mimes"
    const val SIZES = "sizes"
    const val CAPTION = "caption"

    fun intent(exported: List<MediaSendExport.Output>, caption: String): Intent = Intent()
        .putStringArrayListExtra(PATHS, ArrayList(exported.map { it.path }))
        .putStringArrayListExtra(NAMES, ArrayList(exported.map { it.name }))
        .putStringArrayListExtra(MIMES, ArrayList(exported.map { it.mime }))
        .putExtra(SIZES, exported.map { it.sizeBytes }.toLongArray())
        .putExtra(CAPTION, caption)

    /** Channel payload: one map per file, plus the caption. */
    fun toChannelPayload(data: Intent?): Map<String, Any?>? {
        val paths = data?.getStringArrayListExtra(PATHS) ?: return null
        if (paths.isEmpty()) return null
        val names = data.getStringArrayListExtra(NAMES).orEmpty()
        val mimes = data.getStringArrayListExtra(MIMES).orEmpty()
        val sizes = data.getLongArrayExtra(SIZES) ?: LongArray(paths.size)
        return mapOf(
            "caption" to (data.getStringExtra(CAPTION) ?: ""),
            "items" to paths.mapIndexed { index, path ->
                mapOf(
                    "path" to path,
                    "name" to (names.getOrNull(index) ?: "media"),
                    "mime" to (mimes.getOrNull(index) ?: "application/octet-stream"),
                    "size" to (sizes.getOrNull(index) ?: 0L),
                )
            },
        )
    }
}
