package com.ababilx.app.mediasend

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build

/**
 * What "can we read the library" means per Android version, and the one other
 * grant this flow cannot start without.
 *
 * Android 14's *Selected photos* grant counts for the library: the query then
 * returns only the photos the user picked, which is a smaller grid rather than
 * a broken one — so `any`, never `all`.
 *
 * **Camera is not optional here.** `ACTION_IMAGE_CAPTURE` normally needs no
 * permission at all — but only for an app that does not *declare*
 * `android.permission.CAMERA`. Ours does (the manifest needs it for calls), and
 * for a declaring app the system throws `SecurityException` from
 * `startActivityForResult` when the grant is missing instead of just opening
 * the camera app. Thrown out of `onCreate`, that killed the process.
 */
object MediaSendPermissions {

    const val REQUEST_CODE = 4103
    const val CAMERA_REQUEST_CODE = 4104

    private const val CAMERA = "android.permission.CAMERA"

    fun required(): List<String> = when {
        Build.VERSION.SDK_INT >= 34 -> listOf(
            "android.permission.READ_MEDIA_IMAGES",
            "android.permission.READ_MEDIA_VIDEO",
            "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
        )
        Build.VERSION.SDK_INT >= 33 -> listOf(
            "android.permission.READ_MEDIA_IMAGES",
            "android.permission.READ_MEDIA_VIDEO",
        )
        else -> listOf("android.permission.READ_EXTERNAL_STORAGE")
    }

    fun granted(activity: Activity): Boolean = required().any {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun request(activity: Activity) {
        activity.requestPermissions(required().toTypedArray(), REQUEST_CODE)
    }

    fun cameraGranted(activity: Activity): Boolean =
        activity.checkSelfPermission(CAMERA) == PackageManager.PERMISSION_GRANTED

    fun requestCamera(activity: Activity) {
        activity.requestPermissions(arrayOf(CAMERA), CAMERA_REQUEST_CODE)
    }
}
