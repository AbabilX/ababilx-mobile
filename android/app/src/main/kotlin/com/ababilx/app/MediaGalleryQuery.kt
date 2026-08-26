package com.ababilx.app

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log

/**
 * One page of the device's photo and video library, newest first.
 *
 * Signal's attachment keyboard reads MediaStore straight through a cursor
 * rather than launching the system picker, which is why its grid is on screen
 * the moment the sheet opens. This is the same idea: one query over the
 * combined images+video collection, paged, returning only the columns a
 * thumbnail tile needs.
 *
 * Kept separate from [MediaGalleryChannel] so the cursor work stays free of
 * channel plumbing and permission handling.
 */
object MediaGalleryQuery {

    private const val TAG = "MediaGalleryQuery"

    private val PROJECTION = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.DISPLAY_NAME,
        MediaStore.Files.FileColumns.MIME_TYPE,
        MediaStore.Files.FileColumns.SIZE,
        MediaStore.Files.FileColumns.WIDTH,
        MediaStore.Files.FileColumns.HEIGHT,
        MediaStore.Files.FileColumns.DATE_MODIFIED,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.Files.FileColumns.DURATION,
    )

    /**
     * @param kind "all", "image" or "video".
     */
    fun page(context: Context, offset: Int, limit: Int, kind: String): List<Map<String, Any?>> {
        val types = when (kind) {
            "image" -> intArrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE)
            "video" -> intArrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO)
            else -> intArrayOf(
                MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE,
                MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO,
            )
        }
        val selection = types.joinToString(" OR ") { "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?" }
        val args = types.map { it.toString() }.toTypedArray()
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

        return try {
            cursor(context, collection, selection, args, offset, limit)?.use { read(it, offset, limit) }
                ?: emptyList()
        } catch (error: Exception) {
            // A revoked permission surfaces here as a SecurityException. The
            // caller falls back to the system picker rather than showing an
            // empty grid that looks like an empty phone.
            Log.w(TAG, "MediaStore query failed", error)
            emptyList()
        }
    }

    private fun cursor(
        context: Context,
        collection: android.net.Uri,
        selection: String,
        args: Array<String>,
        offset: Int,
        limit: Int,
    ): Cursor? {
        val sort = "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val extras = Bundle().apply {
                putString(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                putString(android.content.ContentResolver.QUERY_ARG_SQL_SORT_ORDER, sort)
                putInt(android.content.ContentResolver.QUERY_ARG_LIMIT, limit)
                putInt(android.content.ContentResolver.QUERY_ARG_OFFSET, offset)
            }
            return context.contentResolver.query(collection, PROJECTION, extras, null)
        }
        // Pre-O has no query-args bundle; LIMIT/OFFSET ride the sort clause.
        return context.contentResolver.query(
            collection,
            PROJECTION,
            selection,
            args,
            "$sort LIMIT $limit OFFSET $offset",
        )
    }

    private fun read(cursor: Cursor, offset: Int, limit: Int): List<Map<String, Any?>> {
        val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
        val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
        val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
        val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
        val widthCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.WIDTH)
        val heightCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.HEIGHT)
        val typeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
        val durationCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.DURATION)

        // Pre-O paging happened in SQL; on O+ the bundle already applied it.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O && offset > 0 && !cursor.moveToPosition(0)) {
            return emptyList()
        }

        val items = mutableListOf<Map<String, Any?>>()
        while (cursor.moveToNext() && items.size < limit) {
            val id = cursor.getLong(idCol)
            val isVideo = cursor.getInt(typeCol) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
            val base = if (isVideo) {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            items += mapOf(
                "uri" to ContentUris.withAppendedId(base, id).toString(),
                "name" to (cursor.getString(nameCol) ?: "media-$id"),
                "mime" to (cursor.getString(mimeCol) ?: if (isVideo) "video/mp4" else "image/jpeg"),
                "size" to cursor.getLong(sizeCol),
                "width" to cursor.getInt(widthCol),
                "height" to cursor.getInt(heightCol),
                "isVideo" to isVideo,
                "durationMs" to if (durationCol >= 0) cursor.getLong(durationCol) else 0L,
            )
        }
        return items
    }
}
