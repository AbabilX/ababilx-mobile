import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'ringtone_watchdog.dart';
import 'voice_call_log.dart';

/// Shared in-app ringtone for both call systems (1:1 DM and channel group).
///
/// Mirrors web `src/lib/calls/ringtone.ts`, but keyed by named holder instead
/// of a plain counter: a DM ring and a group ring can overlap, and the call
/// sites stop unconditionally (screen dispose, terminal phase), so an unmatched
/// stop must not silence the other system's ring.
class CallRingtone {
  CallRingtone._();

  static const _asset = 'ringtone/Clear_Agenda.mp3';

  /// A dismissed CallKit screen abandons its audio focus and tears its ringer
  /// down asynchronously, so a re-play landing inside that window collides
  /// with the teardown. Wait it out before taking the ring back.
  static const _handoffSettle = Duration(milliseconds: 250);

  static final _player = AudioPlayer(playerId: 'ababilx_call_ringtone');
  static final Set<String> _holders = {};
  static bool _playing = false;
  static bool _restart = false;
  static Future<void>? _chain;

  static final _watchdog = RingtoneWatchdog(
    position: () => _player.getCurrentPosition(),
    playing: () => _playing,
    restart: refresh,
    onStall: (position) => voiceCallLog(
      'ringtone.stalled',
      reason: 'position=${position?.inMilliseconds ?? -1}ms',
    ),
  );

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

  /// Play again from the top for whoever is still holding. No-op when nothing
  /// is ringing.
  static Future<void> refresh() {
    if (_holders.isEmpty) return Future<void>.value();
    _restart = true;
    return _apply();
  }

  /// Take the ring back from a native ringer that was just dismissed, once its
  /// teardown has had time to finish. See [_handoffSettle].
  static Future<void> handoff() async {
    if (_holders.isEmpty) return;
    await Future<void>.delayed(_handoffSettle);
    if (_holders.isEmpty) return;
    await refresh();
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
      final restart = want && _restart;
      _restart = false;
      if (want != _playing || restart) {
        if (want) {
          if (restart) await _stop();
          _playing = await _start();
        } else {
          await _stop();
          _playing = false;
        }
      }
      // Guard the tone for as long as anyone wants it, including after a
      // failed start — the watchdog is what retries that.
      if (_holders.isEmpty) {
        _watchdog.stop();
      } else {
        _watchdog.start();
      }
      if (_holders.isNotEmpty == want) return;
    }
  }

  /// True only when the tone is actually running. A failed start must stay
  /// false: recording it as playing made every later hold a no-op, so one
  /// rejected attempt silenced ringing for the rest of the process.
  static Future<bool> _start() async {
    for (final context in [_ringContext, null]) {
      try {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource(_asset), volume: 1, ctx: context);
        _watchdog.reset();
        return true;
      } catch (error) {
        voiceCallLog(
          'ringtone.play.failed',
          source: context == null ? 'default_context' : 'ring_context',
          reason: '$error',
        );
      }
    }
    return false;
  }

  static Future<void> _stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // A missing audio route must never take the call dialog down with it.
    }
  }

  /// Route to the loudspeaker — an incoming call must be audible across the
  /// room — but request **no** audio focus: audioplayers answers a focus loss
  /// by pausing the native player behind Dart's back, so any competing ringer
  /// or notification would silence the call tone for good. Mixing over other
  /// audio is the lesser evil. Some OEMs reject these attributes outright,
  /// which is why [_start] retries with the default context.
  static AudioContext get _ringContext => AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.duckOthers},
    ),
  );
}
