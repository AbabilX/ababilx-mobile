package com.ababilx.app

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log

/**
 * One page of the device's photo and video library, newest first — plus the
 * album/folder list Signal's wallpaper picker opens into.
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

    /** Synthetic bucket that means "every album" — same role as Signal's. */
    const val ALL_MEDIA_BUCKET_ID = "ababilx.ALL_MEDIA"

    private const val CAMERA_FOLDER_NAME = "Camera"

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
     * Album list for the wallpaper (and any future) folder gallery.
     *
     * Order matches Signal: Camera, All media, then every other bucket by
     * title. [kind] is usually `"image"` for wallpaper.
     */
    fun folders(context: Context, kind: String): List<Map<String, Any?>> {
        return try {
            buildFolders(context, kind)
        } catch (error: Exception) {
            Log.w(TAG, "MediaStore folders failed", error)
            emptyList()
        }
    }

    /**
     * @param kind "all", "image" or "video".
     * @param bucketId null / [ALL_MEDIA_BUCKET_ID] = every matching item;
     *   otherwise MediaStore `BUCKET_ID`.
     */
    fun page(
        context: Context,
        offset: Int,
        limit: Int,
        kind: String,
        bucketId: String? = null,
    ): List<Map<String, Any?>> {
        val types = mediaTypes(kind)
        val typeClause = types.joinToString(" OR ") { "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?" }
        val args = mutableListOf(*types.map { it.toString() }.toTypedArray())
        val selection = StringBuilder("($typeClause)")
        if (!bucketId.isNullOrEmpty() && bucketId != ALL_MEDIA_BUCKET_ID) {
            selection.append(" AND ${MediaStore.Files.FileColumns.BUCKET_ID} = ?")
            args += bucketId
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            selection.append(" AND ${MediaStore.Files.FileColumns.IS_PENDING} = 0")
        }
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

        return try {
            cursor(context, collection, selection.toString(), args.toTypedArray(), offset, limit)
                ?.use { read(it, offset, limit) }
                ?: emptyList()
        } catch (error: Exception) {
            // A revoked permission surfaces here as a SecurityException. The
            // caller falls back to the system picker rather than showing an
            // empty grid that looks like an empty phone.
            Log.w(TAG, "MediaStore query failed", error)
            emptyList()
        }
    }

    private fun buildFolders(context: Context, kind: String): List<Map<String, Any?>> {
        val types = mediaTypes(kind)
        val typeClause = types.joinToString(" OR ") { "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?" }
        val args = types.map { it.toString() }.toTypedArray()
        val selection = StringBuilder("($typeClause)")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            selection.append(" AND ${MediaStore.Files.FileColumns.IS_PENDING} = 0")
        }

        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.BUCKET_ID,
            MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val sort =
            "${MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME} COLLATE NOCASE ASC, " +
                "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"

        data class Acc(
            var title: String,
            var count: Int,
            var thumbUri: String,
            var newest: Long,
            var isCamera: Boolean,
        )

        val byBucket = linkedMapOf<String, Acc>()
        var allThumb: String? = null
        var allNewest = 0L
        var allCount = 0
        var cameraBucketId: String? = null

        context.contentResolver.query(
            collection,
            projection,
            selection.toString(),
            args,
            sort,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val bucketCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val typeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)

            while (cursor.moveToNext()) {
                val bucketId = cursor.getString(bucketCol) ?: continue
                val title = cursor.getString(titleCol)?.takeIf { it.isNotBlank() } ?: continue
                val id = cursor.getLong(idCol)
                val isVideo = cursor.getInt(typeCol) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
                val base = if (isVideo) {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                }
                val thumb = ContentUris.withAppendedId(base, id).toString()
                val date = cursor.getLong(dateCol)
                val existing = byBucket[bucketId]
                if (existing == null) {
                    val camera = title.equals(CAMERA_FOLDER_NAME, ignoreCase = true)
                    byBucket[bucketId] = Acc(title, 1, thumb, date, camera)
                    if (camera) cameraBucketId = bucketId
                } else {
                    existing.count += 1
                    // Cursor is newest-first within each bucket title group, so
                    // the first row we see already holds the folder thumbnail.
                }
                allCount += 1
                if (date >= allNewest) {
                    allNewest = date
                    allThumb = thumb
                }
            }
        }

        if (allCount == 0 || allThumb == null) return emptyList()

        val camera = cameraBucketId?.let { id -> id to byBucket.remove(id)!! }
        val normals = byBucket.entries
            .sortedBy { it.value.title.lowercase() }
            .map { (id, acc) ->
                folderRow(acc.thumbUri, acc.title, acc.count, id, false)
            }

        val out = mutableListOf<Map<String, Any?>>()
        if (camera != null) {
            val (id, acc) = camera
            out += folderRow(acc.thumbUri, acc.title, acc.count, id, true)
        }
        out += folderRow(allThumb, "All media", allCount, ALL_MEDIA_BUCKET_ID, false)
        out += normals
        return out
    }

    private fun folderRow(
        thumbnailUri: String,
        title: String,
        count: Int,
        bucketId: String,
        isCamera: Boolean,
    ): Map<String, Any?> = mapOf(
        "bucketId" to bucketId,
        "title" to title,
        "count" to count,
        "thumbnailUri" to thumbnailUri,
        "isCamera" to isCamera,
    )

    private fun mediaTypes(kind: String): IntArray = when (kind) {
        "image" -> intArrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE)
        "video" -> intArrayOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO)
        else -> intArrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE,
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO,
        )
    }

    private fun cursor(
        context: Context,
        collection: Uri,
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
