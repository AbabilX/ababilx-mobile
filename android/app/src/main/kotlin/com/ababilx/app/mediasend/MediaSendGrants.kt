package com.ababilx.app.mediasend

import android.app.Activity
import android.widget.Toast
import com.ababilx.app.R

/** What each answered permission request leads to. */
object MediaSendGrants {

    fun onResult(
        activity: Activity,
        requestCode: Int,
        startGallery: () -> Unit,
        pickers: MediaSendPickers,
        intake: MediaSendIntake,
    ) {
        when (requestCode) {
            // A library refusal is not a dead end: Files needs no permission of
            // ours, so the document picker is offered instead of an empty grid.
            MediaSendPermissions.REQUEST_CODE ->
                if (MediaSendPermissions.granted(activity)) startGallery() else pickers.openFiles()

            // A camera refusal *is* one — there is no other way to take a
            // photo, and this flow was opened to take one. The microphone,
            // asked alongside it, decides nothing here: refused, a video is
            // recorded without sound.
            MediaSendPermissions.CAMERA_REQUEST_CODE ->
                if (MediaSendPermissions.cameraGranted(activity)) {
                    pickers.openCamera()
                } else {
                    Toast.makeText(activity, R.string.media_send_camera_denied, Toast.LENGTH_SHORT)
                        .show()
                    intake.pickerClosedEmpty()
                }
        }
    }
}
