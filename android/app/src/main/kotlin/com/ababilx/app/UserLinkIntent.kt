package com.ababilx.app

import android.content.Intent
import android.net.Uri

/**
 * Reads a shared link: a person's handle or a group's public slug.
 *
 * Two shapes of each reach us: `https://www.ababilx.com/u/<handle>` and
 * `/g/<slug>` (App Links), and `ababilx://user?u=<handle>` /
 * `ababilx://group?g=<slug>` (what a QR code carries, and what the site's
 * button fires). The receiving activity is exported and any app can send any
 * of them, so only something shaped like a handle goes on to Dart — which
 * checks it again against the full rules before any request.
 */
object UserLinkIntent {

    /**
     * What the trampoline forwards instead of the link itself. An ACTION_VIEW
     * intent with data reaching the FlutterActivity is taken by Flutter's own
     * deep linking and pushed at the router as a path — "no routes for
     * location: ababilx://user/?u=…".
     */
    const val ACTION_OPEN = "com.ababilx.app.action.OPEN_USER_LINK"
    const val EXTRA_HANDLE = "com.ababilx.app.extra.USER_HANDLE"
    const val EXTRA_GROUP = "com.ababilx.app.extra.GROUP_SLUG"

    private val HOSTS = setOf("www.ababilx.com", "ababilx.com")
    private val SHAPE = Regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*$")

    /** The intent to forward for a link, or null when it is not one of ours. */
    fun forwardFor(data: Uri?): Intent? {
        if (data == null || !data.isHierarchical) return null
        val (extra, raw) = when (data.scheme?.lowercase()) {
            "https" -> {
                val segments = data.pathSegments
                if (data.host?.lowercase() !in HOSTS || segments.size != 2) return null
                when (segments[0]) {
                    "u" -> EXTRA_HANDLE to segments[1]
                    "g" -> EXTRA_GROUP to segments[1]
                    else -> return null
                }
            }
            "ababilx" -> when (data.host) {
                "user" -> EXTRA_HANDLE to data.getQueryParameter("u")
                "group" -> EXTRA_GROUP to data.getQueryParameter("g")
                else -> return null
            }
            else -> return null
        }
        val value = clean(raw) ?: return null
        return Intent(ACTION_OPEN).putExtra(extra, value)
    }

    /** A forwarded extra, shape-checked again: the launcher is exported. */
    fun forwarded(intent: Intent, extra: String): String? = clean(intent.getStringExtra(extra))

    private fun clean(raw: String?): String? {
        val value = raw?.trim()?.lowercase()?.removePrefix("@") ?: return null
        if (value.length !in 3..32 || !SHAPE.matches(value)) return null
        return value
    }
}
