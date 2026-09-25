import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'ringtone/android_ringtone_engine.dart';
import 'ringtone/asset_ringtone_engine.dart';
import 'ringtone/ringtone_engine.dart';

/// Shared in-app ringtone for both call systems (1:1 DM and channel group).
///
/// Mirrors web `src/lib/calls/ringtone.ts`, but keyed by named holder instead
/// of a plain counter: a DM ring and a group ring can overlap, and the call
/// sites stop unconditionally (screen dispose, terminal phase), so an unmatched
/// stop must not silence the other system's ring.
///
/// *What* actually makes the sound is the platform's [RingtoneEngine]: on
/// Android the native player shared with CallKit, elsewhere the bundled asset.
class CallRingtone {
  CallRingtone._();

  /// A dismissed CallKit screen abandons its audio focus and tears its ringer
  /// down asynchronously, so a re-play landing inside that window collides
  /// with the teardown. Wait it out before taking the ring back. Only the
  /// asset engine needs this — see [RingtoneEngine.replayOnHandoff].
  static const _handoffSettle = Duration(milliseconds: 250);

  static final RingtoneEngine _engine = Platform.isAndroid
      ? AndroidRingtoneEngine()
      : AssetRingtoneEngine(onStall: refresh);

  static final Set<String> _holders = {};
  static bool _playing = false;
  static bool _restart = false;
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

  /// Whether [holder] is asking for the ring right now.
  @visibleForTesting
  static bool holds(String holder) => _holders.contains(holder);

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
    if (!_engine.replayOnHandoff) {
      // Same player on both sides of the hand-off: it is still running, and
      // replaying it would restart the tone from silence for no reason.
      await _apply();
      return;
    }
    await Future<void>.delayed(_handoffSettle);
    if (_holders.isEmpty) return;
    await refresh();
  }

  /// Engine calls are serialized so overlapping hold/release cannot leave the
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
    // Loop until the engine matches the latest desired state (handles churn
    // while awaiting the platform channel).
    while (true) {
      final want = _holders.isNotEmpty;
      final restart = want && _restart;
      _restart = false;
      if (want != _playing || restart) {
        if (want) {
          _playing = restart ? await _engine.restart() : await _engine.start();
        } else {
          await _engine.stop();
          _playing = false;
        }
      }
      // Guard the tone for as long as anyone wants it, including after a
      // failed start — the engine's watchdog is what retries that.
      _engine.guard(wanted: _holders.isNotEmpty, playing: _playing);
      if (_holders.isNotEmpty == want) return;
    }
  }
}
