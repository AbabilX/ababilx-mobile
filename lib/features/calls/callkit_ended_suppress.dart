import 'dart:async';

import 'voice_call_log.dart';

/// One-shot guard: ignore the next CallKit [ACTION_CALL_ENDED] for a callId.
///
/// Armed only before intentional CallKit dismiss after Accept (or before our
/// own [endCall] echo). Consumed on the first matching event, or expires.
class CallKitEndedSuppress {
  String? _callId;
  Timer? _timer;

  String? get callId => _callId;

  bool get isArmed => _callId != null;

  void arm(
    String callId, {
    Duration ttl = const Duration(seconds: 2),
    String source = 'arm',
  }) {
    _timer?.cancel();
    _callId = callId;
    voiceCallLog(
      'callkit.ended.suppress.arm',
      callId: callId,
      source: source,
      suppress: true,
    );
    _timer = Timer(ttl, () {
      if (_callId == callId) {
        voiceCallLog(
          'callkit.ended.suppress.expire',
          callId: callId,
          source: source,
        );
        _callId = null;
      }
    });
  }

  /// Returns true once for the matching callId, then clears.
  bool consume(String callId) {
    if (_callId != callId) return false;
    _timer?.cancel();
    _timer = null;
    _callId = null;
    voiceCallLog(
      'callkit.ended.suppress.consume',
      callId: callId,
      suppress: true,
    );
    return true;
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _callId = null;
  }
}
