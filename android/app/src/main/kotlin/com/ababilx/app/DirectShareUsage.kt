package com.ababilx.app

import android.content.Context
import android.util.Log
import androidx.core.content.pm.ShortcutManagerCompat

/**
 * Tells Android which chats are in use, so the share sheet shows more than one.
 *
 * The sheet does not take our ranks at face value: it asks the system's
 * predictor, which orders share shortcuts by usage history. Publishing alone
 * gives a chat none; the one chat ever picked from the sheet had some, and it
 * was the only one shown.
 * Signal pushes the shortcut on every message sent or received
 * (`ConversationShortcutRankingUpdateJob`); this is the same signal:
 *
 *   first publish for an account -> every target, oldest first (a new install
 *                                   or an update starts with a full row)
 *   a message in a target chat   -> that chat ([report], from Dart)
 *
 * Runs on [DirectShareShortcuts]' worker. How many targets the sheet draws is
 * still the system's call (per app and per row); this only stops it from
 * having nothing to go on.
 */
internal object DirectShareUsage {

    private const val TAG = "DirectShare"
    private const val PREFS = "direct_share"
    private const val SEEDED = "usage_seeded_v1"

    /** Once per account and install, after the first successful publish. */
    fun seed(context: Context, shortcutIds: List<String>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(SEEDED, false)) return
        // Last reported reads as most recent: the list is newest first.
        shortcutIds.asReversed().forEach { use(context, it) }
        prefs.edit().putBoolean(SEEDED, true).apply()
    }

    /** Signed out or disguised: the next account's row starts fresh. */
    fun forget(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(SEEDED).apply()
    }

    /** [conversationIds] oldest first; only chats currently published count. */
    fun report(context: Context, published: List<String>, conversationIds: List<String>) {
        val live = published.toSet()
        conversationIds
            .filter(DirectShareShortcuts::isConversationId)
            .map { DirectShareShortcuts.PREFIX + it }
            .filter { it in live }
            .forEach { use(context, it) }
    }

    private fun use(context: Context, shortcutId: String) {
        try {
            ShortcutManagerCompat.reportShortcutUsed(context, shortcutId)
        } catch (error: Exception) {
            Log.w(TAG, "usage report failed", error)
        }
    }
}
