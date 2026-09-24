package com.ababilx.app.mediasend.review

import android.view.View
import android.widget.ImageButton
import android.widget.Toast
import com.ababilx.app.R
import com.ababilx.app.mediasend.PickedItem

/**
 * The eye beside Remove: send this album as view once.
 *
 * Drawn only when the caller allowed it (a DM with someone else — the server
 * ignores the policy anywhere else) and every item is a photo, the same rule
 * Dart applies before stamping: a video or a file on a one-open clock is
 * something nobody can actually watch or read. A selection that stops being
 * all photos turns it off rather than hiding a choice that still applies.
 */
class ViewOnceToggle(private val button: ImageButton) {

    /** Set once from the request. */
    var allowed: Boolean = false

    var on: Boolean = false
        private set

    init {
        button.setOnClickListener {
            on = !on
            paint()
            Toast.makeText(
                button.context,
                if (on) R.string.media_send_view_once_on else R.string.media_send_view_once_off,
                Toast.LENGTH_SHORT,
            ).show()
        }
    }

    /** Called whenever the selection changes. */
    fun refresh(items: List<PickedItem>) {
        val eligible = allowed && items.isNotEmpty() && items.all(::isPhoto)
        if (!eligible) on = false
        button.visibility = if (eligible) View.VISIBLE else View.GONE
        paint()
    }

    private fun paint() {
        button.setBackgroundResource(
            if (on) R.drawable.ms_circle_accent else R.drawable.ms_circle_button,
        )
        button.isSelected = on
    }

    private fun isPhoto(item: PickedItem) = !item.isVideo && item.mime.startsWith("image/")
}
