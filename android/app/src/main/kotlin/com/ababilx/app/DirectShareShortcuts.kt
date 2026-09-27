package com.ababilx.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.Person
import androidx.core.content.LocusIdCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import java.util.concurrent.Executors

/**
 * Direct Share: recent chats as targets in the system share sheet, each drawn
 * with the chat's picture and the AbabilX badge — the row every messenger gets.
 *
 * They are long-lived dynamic shortcuts in the share-target category declared
 * by `res/xml/share_shortcuts.xml`. Picking one sends the ordinary ACTION_SEND
 * to [ShareIntakeActivity] with EXTRA_SHORTCUT_ID, which [ShareIntakeBridge]
 * turns back into a conversation id. Signal's `ConversationUtil` is the model.
 *
 * The same shortcuts show on a long press of the launcher icon, so they are
 * withheld while a disguise icon is on: a "Calculator" that lists chats is no
 * disguise at all.
 */
object DirectShareShortcuts {

    data class Target(
        val conversationId: String,
        val name: String,
        val avatarUrl: String,
        val isGroup: Boolean,
    )

    const val CATEGORY = "com.ababilx.app.sharing.CATEGORY_SHARE_TARGET"
    const val ACTION_OPEN = "com.ababilx.app.action.OPEN_CONVERSATION"
    const val EXTRA_CONVERSATION_ID = "com.ababilx.app.extra.CONVERSATION_ID"

    private const val TAG = "DirectShare"
    private const val PREFIX = "conv_"

    /** The sheet shows four to eight; more only costs avatar downloads. */
    private const val MAX = 8

    /** Must match the disguise aliases in `AppIconChannel.ALIASES`. */
    private val DISGUISES = setOf(
        "LauncherCalendar",
        "LauncherCalculator",
        "LauncherNotes",
        "LauncherWeather",
    )

    // One worker: avatars are downloaded, and two publishes must not interleave.
    private val worker = Executors.newSingleThreadExecutor()

    /** What Dart last asked for, so switching back from a disguise restores it. */
    @Volatile
    private var last: List<Target> = emptyList()

    fun conversationIdOf(shortcutId: String?): String? =
        shortcutId?.takeIf { it.startsWith(PREFIX) }
            ?.removePrefix(PREFIX)
            ?.takeIf { it.isNotBlank() }

    fun publishAsync(context: Context, targets: List<Target>) {
        last = targets
        val app = context.applicationContext
        worker.execute { publish(app, targets) }
    }

    /** Signed out: nothing of the last account may stay in the share sheet. */
    fun clearAsync(context: Context) {
        last = emptyList()
        val app = context.applicationContext
        worker.execute { removeAll(app) }
    }

    /** Called right after the launcher alias changed. */
    fun onIconChanged(context: Context) {
        val app = context.applicationContext
        worker.execute {
            if (isDisguised(app)) removeAll(app) else if (last.isNotEmpty()) publish(app, last)
        }
    }

    private fun publish(context: Context, targets: List<Target>) {
        try {
            val launcher = launcherComponent(context)
            if (launcher == null || isDisguised(launcher)) {
                removeAll(context)
                return
            }
            val max = minOf(MAX, ShortcutManagerCompat.getMaxShortcutCountPerActivity(context))
            val shortcuts = targets.take(max).mapIndexed { rank, target ->
                build(context, launcher, target, rank)
            }
            val keep = shortcuts.map { it.id }.toSet()
            // Long-lived shortcuts outlive setDynamicShortcuts in the system's
            // cache, so a chat that left the list (locked, left, deleted) has
            // to be removed from there by name.
            val stale = known(context).filter { it !in keep }
            if (stale.isNotEmpty()) ShortcutManagerCompat.removeLongLivedShortcuts(context, stale)
            if (!ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts)) {
                Log.w(TAG, "rate limited; kept the previous targets")
            }
        } catch (error: Exception) {
            Log.w(TAG, "publish failed", error)
        }
    }

    private fun build(
        context: Context,
        launcher: ComponentName,
        target: Target,
        rank: Int,
    ): ShortcutInfoCompat {
        val id = PREFIX + target.conversationId
        val label = target.name.ifBlank { "AbabilX" }
        // A tap from the launcher's long-press menu opens the chat; the share
        // sheet never uses this intent, it sends ACTION_SEND instead.
        val open = Intent(context, ShareIntakeActivity::class.java)
            .setAction(ACTION_OPEN)
            .putExtra(EXTRA_CONVERSATION_ID, target.conversationId)
        val builder = ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(label)
            .setLongLived(true)
            .setIntent(open)
            .setActivity(launcher)
            .setCategories(setOf(CATEGORY))
            .setRank(rank)
            .setLocusId(LocusIdCompat(id))
            .setIcon(DirectShareAvatars.icon(context, target))
        if (!target.isGroup) {
            builder.setPerson(Person.Builder().setName(label).setKey(id).build())
        }
        return builder.build()
    }

    private fun removeAll(context: Context) {
        try {
            val ids = known(context)
            if (ids.isNotEmpty()) ShortcutManagerCompat.removeLongLivedShortcuts(context, ids)
            ShortcutManagerCompat.removeAllDynamicShortcuts(context)
        } catch (error: Exception) {
            Log.w(TAG, "clear failed", error)
        }
    }

    private fun known(context: Context): List<String> =
        ShortcutManagerCompat.getShortcuts(
            context,
            ShortcutManagerCompat.FLAG_MATCH_DYNAMIC or ShortcutManagerCompat.FLAG_MATCH_CACHED,
        ).map { it.id }.filter { it.startsWith(PREFIX) }.distinct()

    /** The launcher alias enabled right now; disabled aliases never resolve. */
    private fun launcherComponent(context: Context): ComponentName? {
        val intent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage(context.packageName)
        val info = context.packageManager.queryIntentActivities(intent, 0)
            .firstOrNull()?.activityInfo ?: return null
        return ComponentName(info.packageName, info.name)
    }

    private fun isDisguised(context: Context): Boolean =
        launcherComponent(context)?.let(::isDisguised) ?: true

    private fun isDisguised(component: ComponentName): Boolean =
        component.className.substringAfterLast('.') in DISGUISES
}
