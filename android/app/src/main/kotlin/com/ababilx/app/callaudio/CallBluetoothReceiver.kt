package com.ababilx.app.callaudio

import android.bluetooth.BluetoothHeadset
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Handler

/**
 * Headset and SCO broadcasts for [CallBluetoothManager] — Signal's
 * `BluetoothHeadsetBroadcastReceiver`. Parses on the main thread, acts on the
 * call-audio thread.
 */
class CallBluetoothReceiver(
    private val manager: CallBluetoothManager,
    private val handler: Handler,
) : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val state = intent.getIntExtra(BluetoothHeadset.EXTRA_STATE, -1)
        val previous = intent.getIntExtra(BluetoothHeadset.EXTRA_PREVIOUS_STATE, -1)
        when (intent.action) {
            BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED ->
                handler.post { manager.onConnectionStateChanged(state) }
            BluetoothHeadset.ACTION_AUDIO_STATE_CHANGED -> {
                val sticky = isInitialStickyBroadcast
                handler.post { manager.onAudioStateChanged(state, previous, sticky) }
            }
            AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED -> {
                val sco = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1)
                val prior = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_PREVIOUS_STATE, -1)
                if (prior == AudioManager.SCO_AUDIO_STATE_CONNECTED && sco == AudioManager.SCO_AUDIO_STATE_DISCONNECTED) {
                    handler.post { manager.onScoDisconnected() }
                }
            }
        }
    }

    companion object {
        fun filter() = IntentFilter().apply {
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_AUDIO_STATE_CHANGED)
            addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        }
    }
}
