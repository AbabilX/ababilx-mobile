import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../voice_call_log.dart';
import 'voice_reconnect_policy.dart';

/// Keeps a connected call alive across network trouble instead of dropping it.
///
/// WebRTC gives up on its own: a peer connection that goes `disconnected` or
/// `failed` never recovers by itself, because the candidate pair it was using
/// is gone. The cure is an ICE restart — new candidates over the existing
/// signalling channel — which is what this drives, on a backoff, until the
/// media flows again or [VoiceReconnectPolicy.giveUpAfter] expires.
///
/// Only the original caller re-offers. A callee that notices the drop first
/// asks the caller to do it ([requestPeerRestart]) rather than offering itself,
/// because two simultaneous offers collide (glare) and neither applies.
class VoiceReconnectController {
  VoiceReconnectController({
    required this.isOfferer,
    required this.restart,
    required this.requestPeerRestart,
    required this.onGaveUp,
    required this.onReconnectingChanged,
    this.policy = const VoiceReconnectPolicy(),
  }) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    // The stream replays the current network to a new subscriber on Android,
    // which would otherwise read as "the interface changed" the instant a call
    // connects and restart a perfectly healthy connection.
    unawaited(_seedNetwork());
  }

  /// True when this device is the one that must create restart offers.
  final bool Function() isOfferer;

  /// Runs one restart attempt: refresh ICE servers, then re-offer.
  final Future<void> Function() restart;

  /// Signals the peer to run [restart] on its side.
  final Future<void> Function() requestPeerRestart;

  final void Function(String reason) onGaveUp;
  final void Function(bool reconnecting) onReconnectingChanged;
  final VoiceReconnectPolicy policy;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  List<ConnectivityResult>? _lastResults;
  Timer? _timer;
  Timer? _deadline;
  DateTime? _unhealthySince;
  int _attempt = 0;

  /// Bumped whenever a recovery episode starts or is re-based. An attempt that
  /// was awaiting a slow TURN fetch when the generation moved must not apply
  /// what it fetched — those ICE servers are older than what has since landed.
  int _generation = 0;
  bool _attemptInFlight = false;
  bool _retryQueued = false;
  bool _disposed = false;

  bool get reconnecting => _unhealthySince != null;

  /// Media is flowing. Clears any recovery in progress.
  void noteHealthy() {
    if (_disposed || _unhealthySince == null) return;
    voiceCallLog('reconnect.recovered', reason: 'attempts=$_attempt');
    _timer?.cancel();
    _timer = null;
    _deadline?.cancel();
    _deadline = null;
    _unhealthySince = null;
    _attempt = 0;
    _generation++;
    _retryQueued = false;
    onReconnectingChanged(false);
  }

  /// The peer connection dropped. [immediate] skips the settle grace for
  /// causes that never heal by waiting (hard failure, interface change).
  void noteTrouble(String reason, {bool immediate = false}) {
    if (_disposed) return;
    if (_unhealthySince != null) return; // recovery already running
    voiceCallLog('reconnect.begin', reason: '$reason immediate=$immediate');
    _unhealthySince = DateTime.now();
    _attempt = 0;
    _generation++;
    _retryQueued = false;
    onReconnectingChanged(true);
    // Independent of the attempt chain on purpose: an attempt that hangs (a
    // socket connect that never returns on a dead network) would otherwise
    // leave the call showing "Reconnecting…" with nothing left to end it.
    _deadline?.cancel();
    _deadline = Timer(policy.giveUpAfter, () => _giveUp('deadline'));
    _schedule(immediate ? Duration.zero : policy.settleDelay);
  }

  /// The peer asked us (the caller) to restart. Starts recovery if the local
  /// side has not noticed the drop yet.
  void noteRestartRequested() {
    if (_disposed) return;
    if (_unhealthySince == null) {
      noteTrouble('peer_requested_restart', immediate: true);
      return;
    }
    _schedule(Duration.zero);
  }

  Future<void> _seedNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (_disposed) return;
      _lastResults ??= results;
    } catch (_) {
      // No baseline: the first stream event becomes the baseline instead.
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_disposed) return;
    final previous = _lastResults;
    _lastResults = results;
    // First value is the current state, not a change. Acting on it would
    // restart a healthy call the moment the controller is built.
    if (previous == null) return;
    if (_sameNetwork(previous, results)) return;
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    voiceCallLog(
      'reconnect.network',
      reason: results.map((r) => r.name).join(','),
    );
    // Going offline is not actionable — there is nothing to restart onto, and
    // the give-up clock should not start until a route exists again. Coming
    // back, or switching WiFi <-> mobile, is exactly when a restart works.
    if (offline) return;
    if (_unhealthySince != null) {
      // A route exists again, so the recovery budget restarts here. Otherwise
      // an outage longer than giveUpAfter would kill the call at the very
      // moment it became recoverable — the opposite of what it is for.
      _unhealthySince = DateTime.now();
      _attempt = 0;
      _generation++;
      _deadline?.cancel();
      _deadline = Timer(policy.giveUpAfter, () => _giveUp('deadline'));
      _schedule(Duration.zero);
    } else {
      noteTrouble('network_changed', immediate: true);
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _attemptRestart);
  }

  Future<void> _attemptRestart() async {
    if (_disposed) return;
    final since = _unhealthySince;
    if (since == null) return;
    // Never run two attempts at once. A restart awaits a network round trip
    // (fresh TURN credentials), and a second attempt starting underneath it
    // would race: whichever fetch returns last wins, which is not necessarily
    // the newest. Queue instead, and run it when this one lands.
    if (_attemptInFlight) {
      _retryQueued = true;
      return;
    }
    if (policy.exhausted(DateTime.now().difference(since))) {
      _giveUp('attempts');
      return;
    }
    final generation = _generation;
    final attempt = _attempt++;
    _attemptInFlight = true;
    try {
      if (isOfferer()) {
        voiceCallLog('reconnect.restart', reason: 'attempt=$attempt');
        await restart();
      } else {
        voiceCallLog('reconnect.request', reason: 'attempt=$attempt');
        await requestPeerRestart();
      }
    } catch (error) {
      voiceCallLog('reconnect.attempt.failed', reason: error.toString());
    } finally {
      _attemptInFlight = false;
    }
    if (_disposed || _unhealthySince == null) return;
    // A queued retry, or a generation that moved while this attempt was in
    // flight, both mean "the situation changed" — go again now rather than
    // sitting out this attempt's backoff.
    if (_retryQueued || generation != _generation) {
      _retryQueued = false;
      _schedule(Duration.zero);
      return;
    }
    // Keep a retry queued: a restart offer can itself be lost, and the peer
    // may still be offline. noteHealthy() cancels this the moment media flows.
    _schedule(policy.delayFor(_attempt));
  }

  void _giveUp(String source) {
    if (_disposed || _unhealthySince == null) return;
    final unhealthyFor = DateTime.now().difference(_unhealthySince!);
    voiceCallLog(
      'reconnect.gaveUp',
      reason:
          'source=$source after=${unhealthyFor.inSeconds}s '
          'attempts=$_attempt',
    );
    _timer?.cancel();
    _timer = null;
    _deadline?.cancel();
    _deadline = null;
    _unhealthySince = null;
    _generation++;
    _retryQueued = false;
    onGaveUp('peer_connection_disconnected');
  }

  static bool _sameNetwork(
    List<ConnectivityResult> a,
    List<ConnectivityResult> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _deadline?.cancel();
    _deadline = null;
    _unhealthySince = null;
    _generation++;
    _retryQueued = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
