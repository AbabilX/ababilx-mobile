package com.ababilx.app

import android.net.Uri

/**
 * Reads the handle out of a personal message link.
 *
 * Two shapes reach us: `https://www.ababilx.com/u/<handle>` (an App Link) and
 * `ababilx://user?u=<handle>` (what a personal QR code carries, and what the
 * site's "Open in AbabilX" button fires). The receiving activity is exported
 * and any app can send either, so only something shaped like a handle goes on
 * to Dart — which checks it again against the full rules before any request.
 */
object UserLinkIntent {

    private val HOSTS = setOf("www.ababilx.com", "ababilx.com")
    private val SHAPE = Regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*$")

    /**
     * What the trampoline forwards instead of the link itself. An ACTION_VIEW
     * intent with data reaching the FlutterActivity is taken by Flutter's own
     * deep linking and pushed at the router as a path — "no routes for
     * location: ababilx://user/?u=…".
     */
    const val ACTION_OPEN = "com.ababilx.app.action.OPEN_USER_LINK"
    const val EXTRA_HANDLE = "com.ababilx.app.extra.USER_HANDLE"

    /** The forwarded handle, shape-checked again: the launcher is exported. */
    fun forwardedHandle(raw: String?): String? = clean(raw)

    fun handleOf(data: Uri?): String? {
        if (data == null || !data.isHierarchical) return null
        val raw = when (data.scheme?.lowercase()) {
            "https" -> {
                val segments = data.pathSegments
                if (data.host?.lowercase() !in HOSTS) return null
                if (segments.size != 2 || segments[0] != "u") return null
                segments[1]
            }
            "ababilx" -> {
                if (data.host != "user") return null
                data.getQueryParameter("u")
            }
            else -> return null
        }
        return clean(raw)
    }

    private fun clean(raw: String?): String? {
        val handle = raw?.trim()?.lowercase()?.removePrefix("@") ?: return null
        if (handle.length !in 3..32 || !SHAPE.matches(handle)) return null
        return handle
    }
}
