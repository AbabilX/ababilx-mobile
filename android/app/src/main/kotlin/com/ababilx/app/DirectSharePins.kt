package com.ababilx.app

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat

/**
 * Direct Share shortcuts the user dragged from the launcher's long press onto
 * the home screen. Removing the dynamic shortcut leaves that pinned copy in
 * place with the chat's name and picture on it — after sign-out, under a
 * disguise icon, over a chat just locked. So those three cases retire it:
 * repainted blank first (a disabled pin still shows its label and icon,
 * greyed), then disabled. It comes back the next time that chat is a target.
 */
object DirectSharePins {

    private const val TAG = "DirectShare"
    private const val BLANK_LABEL = "Shortcut"

    fun pinnedIds(context: Context, prefix: String): List<String> =
        pinned(context).map { it.id }.filter { it.startsWith(prefix) }

    fun retire(context: Context, ids: Collection<String>) {
        if (ids.isEmpty()) return
        try {
            val live = pinned(context).filter { it.id in ids && it.isEnabled }
            if (live.isEmpty()) return
            val blank = DirectShareAvatars.blank(context)
            val intent = Intent(context, ShareIntakeActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
            ShortcutManagerCompat.updateShortcuts(
                context,
                live.map {
                    ShortcutInfoCompat.Builder(context, it.id)
                        .setShortLabel(BLANK_LABEL)
                        .setIcon(blank)
                        .setIntent(intent)
                        .build()
                },
            )
            ShortcutManagerCompat.disableShortcuts(context, live.map { it.id }, null)
        } catch (error: Exception) {
            Log.w(TAG, "retiring pins failed", error)
        }
    }

    /** Re-enables a retired pin that is a target again, before it is republished. */
    fun restore(context: Context, shortcuts: List<ShortcutInfoCompat>) {
        try {
            val disabled = pinned(context).filter { !it.isEnabled }.map { it.id }.toSet()
            val back = shortcuts.filter { it.id in disabled }
            if (back.isEmpty()) return
            ShortcutManagerCompat.enableShortcuts(context, back)
            ShortcutManagerCompat.updateShortcuts(context, back)
        } catch (error: Exception) {
            Log.w(TAG, "restoring pins failed", error)
        }
    }

    private fun pinned(context: Context): List<ShortcutInfoCompat> =
        ShortcutManagerCompat.getShortcuts(context, ShortcutManagerCompat.FLAG_MATCH_PINNED)
}
