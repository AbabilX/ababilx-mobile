package com.ababilx.app

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.util.Log

/**
 * The ringback's player — Signal's `OutgoingRinger.start`: a looping
 * [MediaPlayer] on `USAGE_VOICE_COMMUNICATION` / `CONTENT_TYPE_SPEECH`,
 * playing our own `res/raw/call_ringback.wav` — or `call_connecting.wav`, the
 * short "pip-pip" that repeats while an answered call sets its media up.
 *
 * Two additions Signal does not need to make, both so a ring never goes
 * quiet while the screen still says "Ringing…": a player error hands the
 * dead player to [onDead] (the owner makes a new one), and a looping player
 * that reports completion anyway is started again.
 */
object CallRingbackPlayer {

    private const val TAG = "CallRingback"

    /** Dart's name for a tone -> our own file in `res/raw`. */
    fun resource(tone: String?): Int =
        if (tone == TONE_CONNECTING) R.raw.call_connecting else R.raw.call_ringback

    const val TONE_RINGBACK = "ringback"
    const val TONE_CONNECTING = "connecting"

    fun create(context: Context, resource: Int, onDead: (MediaPlayer) -> Unit): MediaPlayer? {
        val player = MediaPlayer()
        player.setOnErrorListener { failed, what, extra ->
            Log.w(TAG, "player error what=$what extra=$extra; restarting")
            runCatching { failed.release() }
            onDead(failed)
            true
        }
        player.setOnCompletionListener { done ->
            Log.w(TAG, "player completed while looping; restarting")
            runCatching {
                done.seekTo(0)
                done.start()
            }
        }
        return runCatching {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .build(),
            )
            player.isLooping = true
            player.setDataSource(
                context,
                Uri.parse("android.resource://${context.packageName}/$resource"),
            )
            player.prepare()
            player.start()
            player
        }.onFailure {
            Log.w(TAG, "ringback start failed", it)
            runCatching { player.release() }
        }.getOrNull()
    }
}
