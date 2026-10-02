package com.ababilx.app.mediasend

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * The two escapes out of the library grid — and, when the flow is opened
 * straight at one of them, its front door.
 *
 * Camera comes *back into* the flow: a shot lands in the review screen with
 * the rest of the album. Documents are partitioned by the caller — a picture
 * or a video joins the review screen, a PDF has nothing to review and is
 * reported straight through.
 *
 * [onNothing] fires when a picker closes empty-handed, which is the only way
 * the Activity can tell that a flow opened *at* the camera has been cancelled
 * and should close rather than fall back to a grid nobody asked for.
 */
class MediaSendPickers(
    private val activity: Activity,
    private val maxDocuments: Int,
    private val onCaptured: (PickedItem) -> Unit,
    private val onDocuments: (List<PickedItem>) -> Unit,
    private val onNothing: () -> Unit = {},
    private val onInAppCamera: () -> Unit = {},
    private val withMicrophone: Boolean = true,
) {

    private var cameraTarget: File? = null

    /**
     * Opens our own camera screen, asking for the CAMERA grant first when we
     * do not have it — and for the microphone alongside it, as Signal does,
     * so a video has sound. A refused microphone only costs the sound. The
     * caller re-enters here once the grant lands — see
     * `MediaSendActivity.onRequestPermissionsResult`.
     */
    fun openCamera() {
        if (!MediaSendPermissions.cameraGranted(activity)) {
            MediaSendPermissions.requestCamera(activity, withMicrophone)
            return
        }
        onInAppCamera()
    }

    /**
     * Hands off to the phone's camera app — only when CameraX could open no
     * camera at all. The CAMERA grant is not optional here either: this app
     * declares it, and for a declaring app the system throws
     * `SecurityException` out of `startActivityForResult` rather than opening
     * the camera.
     */
    fun openSystemCamera() {
        if (!MediaSendPermissions.cameraGranted(activity)) {
            onNothing()
            return
        }
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
        if (intent.resolveActivity(activity.packageManager) == null) {
            onNothing()
            return
        }
        // Belt and braces: no OEM camera Activity may take the whole process
        // down from inside onCreate. Anything thrown here reads as "no shot".
        runCatching { activity.startActivityForResult(intent, REQUEST_CAMERA) }
            .onFailure {
                Log.w(TAG, "camera refused to start", it)
                onNothing()
            }
    }

    fun openFiles() {
        runCatching {
            activity.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*")
                    .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true),
                REQUEST_FILES,
            )
        }.onFailure {
            Log.w(TAG, "document picker refused to start", it)
            onNothing()
        }
    }

    /** @return true when the result belonged to one of these pickers. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CAMERA && requestCode != REQUEST_FILES) return false
        if (resultCode != Activity.RESULT_OK) {
            onNothing()
            return true
        }
        when (requestCode) {
            REQUEST_CAMERA -> {
                val file = cameraTarget?.takeIf { it.length() > 0 }
                if (file == null) {
                    onNothing()
                } else {
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
            REQUEST_FILES -> {
                val picked = documents(data)
                if (picked.isEmpty()) onNothing() else onDocuments(picked)
            }
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
        const val TAG = "MediaSendPickers"
        const val REQUEST_CAMERA = 4101
        const val REQUEST_FILES = 4102
    }
}
