package com.ababilx.app

import android.content.res.Configuration
import android.graphics.Rect
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.MarginLayoutParams
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.roundToInt
import com.hiennv.flutter_callkit_incoming.R as CR

/**
 * The full-screen ringing surface (`patches/callkit/activity_callkit_incoming.xml`)
 * on every phone width Android allows.
 *
 * Reported: "on a small phone the Accept button overflows". The pair was two
 * 180dp seats and a 56dp gap inside 30dp padding — 476dp on screens 320–411dp
 * wide — so the LinearLayout squeezed the second seat and Accept was cut off.
 */
@RunWith(AndroidJUnit4::class)
class CallkitIncomingLayoutTest {

    private class Laid(val root: View, val density: Float, val width: Int, val height: Int) {
        fun rect(id: Int): Rect {
            val view = root.findViewById<View>(id)
            var left = 0
            var top = 0
            var at: View? = view
            while (at != null && at !== root) {
                left += at.left
                top += at.top
                at = at.parent as? View
            }
            return Rect(left, top, left + view.width, top + view.height)
        }

        fun dp(px: Int) = px / density
    }

    /** Inflates the ringing layout for a screen of [widthDp] x [heightDp]. */
    private fun lay(widthDp: Int, heightDp: Int): Laid {
        val base = InstrumentationRegistry.getInstrumentation().targetContext
        val config = Configuration(base.resources.configuration).apply {
            screenWidthDp = widthDp
            screenHeightDp = heightDp
            smallestScreenWidthDp = minOf(widthDp, heightDp)
            orientation = Configuration.ORIENTATION_PORTRAIT
        }
        val context = ContextThemeWrapper(
            base.createConfigurationContext(config),
            CR.style.CallkitIncomingTheme,
        )
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).roundToInt()
        val height = (heightDp * density).roundToInt()
        val root = LayoutInflater.from(context)
            .inflate(CR.layout.activity_callkit_incoming, null)
        // What CallkitIncomingActivity.initView does at runtime, with a 24dp
        // status bar and a 48dp three-button navigation bar (the tallest).
        root.findViewById<View>(CR.id.llBackgroundAnimation).layoutParams.height =
            width + (24 * density).roundToInt()
        val action = root.findViewById<View>(CR.id.llAction)
        (action.layoutParams as MarginLayoutParams).bottomMargin =
            (48 * density).roundToInt() +
            context.resources.getDimensionPixelSize(CR.dimen.size_action_lift)
        root.findViewById<TextView>(CR.id.tvNameCaller).text =
            "A caller with a very long display name that cannot fit"
        root.findViewById<TextView>(CR.id.tvNumber).text = "AbabilX voice call"
        // A 1:1 call shows the decline-with-message pill; lay out that case.
        root.findViewById<TextView>(CR.id.tvDeclineMessage).visibility = View.VISIBLE
        root.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
        )
        root.layout(0, 0, width, height)
        return Laid(root, density, width, height)
    }

    /** Views and their animators belong to the main thread; so does this check. */
    private fun assertFits(widthDp: Int, heightDp: Int) {
        var failure: Throwable? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            failure = runCatching { check(widthDp, heightDp) }.exceptionOrNull()
        }
        failure?.let { throw it }
    }

    private fun check(widthDp: Int, heightDp: Int) {
        val laid = lay(widthDp, heightDp)
        val screen = Rect(0, 0, laid.width, laid.height)
        val where = "${widthDp}x${heightDp}dp"

        val accept = laid.rect(CR.id.ivAcceptCall)
        val decline = laid.rect(CR.id.ivDeclineCall)
        for ((name, button) in listOf("Accept" to accept, "Decline" to decline)) {
            assertTrue("$name off screen at $where: $button", screen.contains(button))
            assertEquals("$name is not round at $where: $button", button.width(), button.height())
            assertTrue("$name under 64dp at $where", laid.dp(button.width()) >= 64f)
            // Its seat must hold it whole: a narrower seat clips the circle.
            val seat = laid.root.findViewById<View>(
                if (name == "Accept") CR.id.ivAcceptCall else CR.id.ivDeclineCall,
            ).parent as ViewGroup
            assertTrue("$name wider than its seat at $where", seat.width >= button.width())
        }
        assertEquals("Accept and Decline differ at $where", decline.width(), accept.width())
        assertTrue("Decline overlaps Accept at $where", decline.right <= accept.left)
        assertTrue(
            "the pair is not centred at $where",
            kotlin.math.abs(decline.left - (laid.width - accept.right)) <= 2,
        )

        for (id in listOf(CR.id.tvAccept, CR.id.tvDecline)) {
            val label = laid.root.findViewById<TextView>(id)
            val box = laid.rect(id)
            assertTrue("label off screen at $where: $box", screen.contains(box))
            assertTrue(
                "label clipped at $where: ${box.height()}px for ${label.textSize}px text",
                box.height() >= label.lineHeight,
            )
        }

        val name = laid.rect(CR.id.tvNameCaller)
        assertTrue("name off screen at $where: $name", name.left >= 0 && name.right <= laid.width)
        val actions = laid.rect(CR.id.llAction)
        assertTrue("name runs into the buttons at $where", name.bottom <= actions.top)
        val message = laid.rect(CR.id.tvDeclineMessage)
        assertTrue("Message pill off screen at $where: $message", screen.contains(message))
        assertTrue("Message pill squashed at $where", laid.dp(message.height()) >= 40f)
        assertTrue("name runs into the Message pill at $where", name.bottom <= message.top)
        assertTrue("Message pill overlaps the pair at $where", message.bottom <= actions.top)
        assertTrue("buttons below the screen at $where", actions.bottom <= laid.height)
    }

    @Test fun smallestPhone() = assertFits(320, 569)

    @Test fun compact16by9() = assertFits(360, 640)

    @Test fun compactTall() = assertFits(360, 780)

    @Test fun pixel() = assertFits(393, 852)

    @Test fun large() = assertFits(411, 914)

    @Test fun displaySizeLargest() = assertFits(336, 747)
}
