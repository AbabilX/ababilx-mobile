package com.ababilx.app.mediasend

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.FileProvider
import java.io.File

/**
 * The two escapes out of the library grid.
 *
 * Camera comes *back into* the flow — a shot lands in the review screen with
 * the rest of the album. Documents leave it: a PDF has nothing to review and
 * nothing to edit, so it is reported straight to the caller.
 */
class MediaSendPickers(
    private val activity: Activity,
    private val maxDocuments: Int,
    private val onCaptured: (PickedItem) -> Unit,
    private val onDocuments: (List<PickedItem>) -> Unit,
) {

    private var cameraTarget: File? = null

    fun openCamera() {
        val file = MediaSendExport.cacheFile(activity, "camera.jpg")
        cameraTarget = file
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.mediasend.fileprovider",
            file,
        )
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            .putExtra(MediaStore.EXTRA_OUTPUT, uri)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        if (intent.resolveActivity(activity.packageManager) != null) {
            activity.startActivityForResult(intent, REQUEST_CAMERA)
        }
    }

    fun openFiles() {
        activity.startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("*/*")
                .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true),
            REQUEST_FILES,
        )
    }

    /** @return true when the result belonged to one of these pickers. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CAMERA && requestCode != REQUEST_FILES) return false
        if (resultCode != Activity.RESULT_OK) return true
        when (requestCode) {
            REQUEST_CAMERA -> cameraTarget?.let { file ->
                if (file.length() > 0) {
                    onCaptured(
                        PickedItem(
                            Uri.fromFile(file),
                            file.name,
                            "image/jpeg",
                            false,
                            file.length(),
                        ),
                    )
                }
            }
            REQUEST_FILES -> documents(data).takeIf { it.isNotEmpty() }?.let(onDocuments)
        }
        return true
    }

    private fun documents(data: Intent?): List<PickedItem> {
        val uris = mutableListOf<Uri>()
        data?.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
        }
        data?.data?.let(uris::add)
        return uris.take(maxDocuments).map { uri ->
            PickedItem(
                uri = uri,
                name = MediaSendExport.displayName(activity, uri, "file"),
                mime = activity.contentResolver.getType(uri) ?: "application/octet-stream",
                isVideo = false,
                sizeBytes = 0,
            )
        }
    }

    private companion object {
        const val REQUEST_CAMERA = 4101
        const val REQUEST_FILES = 4102
    }
}
