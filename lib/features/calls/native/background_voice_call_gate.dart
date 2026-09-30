import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/models/voice_call.dart';
import '../data/voice_call_api.dart';
import 'android_call_ui.dart';
import 'call_answered_guard.dart';
import 'voice_call_ended_guard.dart';

typedef VoiceCallLookup = Future<VoiceCall> Function(String callId);
typedef CallIdCheck = Future<bool> Function(String callId);
typedef CallIdAction = Future<void> Function(String callId);

/// Admission for a data-only incoming-call push: ring first, ask second.
///
/// It used to be the other way round, and fail-closed: the phone asked the API
/// whether the call still rang and stayed silent on any error. From a sleeping
/// phone that is the hardest request there is — a Dart isolate booted from
/// nothing, an access token that expired while the phone slept (401, refresh,
/// retry: three HTTPS round trips), a radio still waking up, all inside six
/// seconds and inside the short network window FCM grants a high-priority
/// push. Data Saver or an OEM background-data block failed it every time. Each
/// failure was a call that never rang, and a high-priority push that showed
/// nothing — the very pattern that makes FCM demote the next ones.
///
/// The push is enough to ring on: it names the caller and carries its own
/// expiry, FCM drops it after that (TTL ≤ 60 s), the notification service
/// drops it when it queued too long, and the ended push shares its collapse
/// key. What only the server knows — "that call is already over" — is asked
/// after the ring is up, and only a definite answer takes it down.
class BackgroundVoiceCallGate {
  const BackgroundVoiceCallGate._();

  /// Local checks only; never touches the network.
  static Future<bool> shouldPresent(
    Map<String, dynamic> data, {
    CallIdCheck? endedLookup,
    CallIdCheck? answeredLookup,
    DateTime? now,
  }) async {
    final callId = data['call_id']?.toString() ?? '';
    if (callId.isEmpty) return false;
    final clock = now ?? DateTime.now();
    final pushedExpiry = DateTime.tryParse(
      data['expires_at']?.toString() ?? '',
    )?.toLocal();
    if (pushedExpiry != null && !pushedExpiry.isAfter(clock)) return false;

    final wasEnded = endedLookup ?? VoiceCallEndedGuard.wasEnded;
    if (await wasEnded(callId)) return false;
    // A redelivered offer for a call this device already picked up.
    final answered = answeredLookup ?? CallAnsweredGuard.answeredHere;
    return !await answered(callId);
  }

  /// Once the ring is up: takes it down if the server says the call is over.
  ///
  /// Anything short of that — offline, slow, 401, 404 — leaves it ringing; the
  /// ended push, the server's expiry sweep and CallKit's own timeout all still
  /// end it. `accepted` is never "over": it may be this device's own answer
  /// landing before the answered mark is written, and ending that would hang
  /// up the call the user just picked up. Another device's answer is the
  /// `voice_call_answered` push's job. Returns whether it dismissed.
  static Future<bool> dismissIfOver(
    String callId, {
    VoiceCallLookup? lookup,
    CallIdAction? markEnded,
    CallIdAction? dismiss,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (callId.isEmpty) return false;
    final VoiceCall call;
    try {
      call = await (lookup ?? _lookup)(callId).timeout(timeout);
    } catch (_) {
      return false;
    }
    if (call.id != callId || !call.isTerminal) return false;
    await (markEnded ?? VoiceCallEndedGuard.markEnded)(callId);
    await (dismiss ?? AndroidCallUi.endCall)(callId);
    return true;
  }

  static Future<VoiceCall> _lookup(String callId) async {
    const storage = SecureStorage(FlutterSecureStorage());
    final api = VoiceCallApi(ApiClient(storage));
    return (await api.get(callId)).call;
  }
}
