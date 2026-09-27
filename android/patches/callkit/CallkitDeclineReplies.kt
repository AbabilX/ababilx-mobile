package com.hiennv.flutter_callkit_incoming

import android.app.Activity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView

/**
 * AbabilX: "decline with a message" on the full-screen ringing Activity — the
 * locked-phone and killed-app surface, where the Flutter screen cannot run.
 *
 * Dart puts the choices on the call's `extra` map (1:1 calls only, so a group
 * invite shows no Message button): `decline_replies` is the preset list joined
 * by '\n', the labels ride beside it in the app's language. A pick declines
 * exactly like the red button, with `decline_message` added to the extra map
 * of the decline broadcast. Dart reads it off the decline event in whichever
 * isolate receives it and sends the text sealed, the same way a reply typed
 * into the notification shade is sent — the text never passes the server in
 * the clear. Presets only: typing on a locked screen is not offered, the
 * in-app screen has a free-text field.
 */
object CallkitDeclineReplies {
    private const val REPLIES = "decline_replies"
    private const val BUTTON = "decline_replies_button"
    private const val TITLE = "decline_replies_title"
    private const val CANCEL = "decline_replies_cancel"
    const val MESSAGE = "decline_message"

    @Suppress("UNCHECKED_CAST", "DEPRECATION")
    private fun extra(data: Bundle?): Map<String, Any?> =
        (data?.getSerializable(CallkitConstants.EXTRA_CALLKIT_EXTRA) as? Map<String, Any?>)
            ?: emptyMap()

    private fun label(data: Bundle?, key: String, fallback: String): String =
        (extra(data)[key] as? String)?.takeIf { it.isNotBlank() } ?: fallback

    fun replies(data: Bundle?): List<String> =
        (extra(data)[REPLIES] as? String).orEmpty()
            .split('\n').map { it.trim() }.filter { it.isNotEmpty() }

    /** A copy of [data] whose extra map also carries [text]. */
    fun withMessage(data: Bundle?, text: String): Bundle? {
        if (data == null) return null
        val copy = Bundle(data)
        val next = HashMap(extra(data))
        next[MESSAGE] = text
        copy.putSerializable(CallkitConstants.EXTRA_CALLKIT_EXTRA, next)
        return copy
    }

    fun bind(activity: Activity, data: Bundle?, onPick: (String) -> Unit) {
        val pill = activity.findViewById<TextView>(R.id.tvDeclineMessage) ?: return
        val panel = activity.findViewById<LinearLayout>(R.id.llDeclineReplies) ?: return
        val choices = replies(data)
        if (choices.isEmpty()) {
            pill.visibility = View.GONE
            return
        }
        pill.text = label(data, BUTTON, "Message")
        pill.visibility = View.VISIBLE
        pill.setOnClickListener { open(activity, data, choices, onPick) }
        panel.setPadding(
            panel.paddingLeft,
            panel.paddingTop,
            panel.paddingRight,
            panel.paddingBottom + Utils.getNavigationBarHeight(activity),
        )
    }

    /** Back closes the panel; returns false when there was nothing to close. */
    fun close(activity: Activity): Boolean {
        val panel = activity.findViewById<View>(R.id.llDeclineReplies) ?: return false
        if (panel.visibility != View.VISIBLE) return false
        panel.visibility = View.GONE
        activity.findViewById<View>(R.id.llAction)?.visibility = View.VISIBLE
        activity.findViewById<View>(R.id.tvDeclineMessage)?.visibility = View.VISIBLE
        return true
    }

    private fun open(
        activity: Activity,
        data: Bundle?,
        choices: List<String>,
        onPick: (String) -> Unit,
    ) {
        val panel = activity.findViewById<LinearLayout>(R.id.llDeclineReplies) ?: return
        panel.removeAllViews()
        panel.addView(row(activity, label(data, TITLE, "Decline with message"), title = true))
        choices.forEach { text ->
            panel.addView(row(activity, text).apply { setOnClickListener { onPick(text) } })
        }
        panel.addView(
            row(activity, label(data, CANCEL, "Cancel"), muted = true).apply {
                setOnClickListener { close(activity) }
            },
        )
        activity.findViewById<View>(R.id.llAction)?.visibility = View.INVISIBLE
        activity.findViewById<View>(R.id.tvDeclineMessage)?.visibility = View.INVISIBLE
        panel.visibility = View.VISIBLE
    }

    private fun row(
        activity: Activity,
        text: String,
        title: Boolean = false,
        muted: Boolean = false,
    ): TextView {
        val density = activity.resources.displayMetrics.density
        return TextView(activity).apply {
            this.text = text
            maxLines = 2
            gravity = if (title || muted) Gravity.CENTER else Gravity.START or Gravity.CENTER_VERTICAL
            setTextColor(if (title || muted) 0xB3FFFFFF.toInt() else 0xFFFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (title) 14f else 16f)
            minHeight = (52 * density).toInt()
            val side = (20 * density).toInt()
            setPadding(side, 0, side, 0)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            if (!title) {
                val ripple = TypedValue()
                activity.theme.resolveAttribute(
                    android.R.attr.selectableItemBackground, ripple, true,
                )
                setBackgroundResource(ripple.resourceId)
            }
        }
    }
}
