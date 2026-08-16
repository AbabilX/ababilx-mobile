import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Shared in-app ringtone for both call systems (1:1 DM and channel group).
///
/// Mirrors web `src/lib/calls/ringtone.ts`, but keyed by named holder instead
/// of a plain counter: a DM ring and a group ring can overlap, and the call
/// sites stop unconditionally (screen dispose, terminal phase), so an unmatched
/// stop must not silence the other system's ring.
class CallRingtone {
  CallRingtone._();

  static const _asset = 'ringtone/Clear_Agenda.mp3';

  static final _player = AudioPlayer(playerId: 'ababilx_call_ringtone');
  static final Set<String> _holders = {};
  static bool _playing = false;
  static Future<void>? _chain;

  /// Ring on behalf of [holder] (`dm`, `group`, …). Idempotent.
  static Future<void> hold(String holder) {
    _holders.add(holder);
    return _apply();
  }

  /// Release [holder]. Ringing continues while any other holder remains.
  static Future<void> release(String holder) {
    _holders.remove(holder);
    return _apply();
  }

  static Future<void> releaseAll() {
    _holders.clear();
    return _apply();
  }

  /// Native calls are serialized so overlapping hold/release cannot leave the
  /// tone stuck on, and so two starts never stack a second stream.
  static Future<void> _apply() {
    final previous = _chain;
    late final Future<void> next;
    next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _applyDesired();
    }();
    _chain = next;
    return next;
  }

  static Future<void> _applyDesired() async {
    // Loop until native matches the latest desired state (handles churn while
    // awaiting the platform channel).
    while (true) {
      final want = _holders.isNotEmpty;
      if (want != _playing) {
        try {
          if (want) {
            await _player.setReleaseMode(ReleaseMode.loop);
            await _player.play(
              AssetSource(_asset),
              volume: 1,
              // Ring over other audio and route to the loudspeaker, not the
              // earpiece — an incoming call must be audible across the room.
              ctx: AudioContext(
                android: const AudioContextAndroid(
                  isSpeakerphoneOn: true,
                  contentType: AndroidContentType.music,
                  usageType: AndroidUsageType.notificationRingtone,
                  audioFocus: AndroidAudioFocus.gainTransient,
                ),
                iOS: AudioContextIOS(
                  category: AVAudioSessionCategory.playback,
                  options: const {AVAudioSessionOptions.duckOthers},
                ),
              ),
            );
          } else {
            await _player.stop();
          }
          _playing = want;
        } catch (_) {
          // A missing audio route must never take the call dialog down with it.
          _playing = want;
        }
      }
      if (_holders.isNotEmpty == want) return;
    }
  }
}
