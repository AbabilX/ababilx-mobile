import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/models/voice_call.dart';
import '../data/voice_call_api.dart';
import 'voice_call_ended_guard.dart';

typedef VoiceCallLookup = Future<VoiceCall> Function(String callId);
typedef EndedCallLookup = Future<bool> Function(String callId);

/// Fail-closed admission for a data-only incoming-call push.
///
/// A push is only permission to ask the API; the current server row is the
/// authority. This prevents an out-of-order or redelivered offer from
/// resurrecting a cancelled/accepted/expired call on a killed app.
class BackgroundVoiceCallGate {
  const BackgroundVoiceCallGate._();

  static Future<bool> shouldPresent(
    Map<String, dynamic> data, {
    VoiceCallLookup? lookup,
    EndedCallLookup? endedLookup,
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

    try {
      final call = await (lookup ?? _lookup)(
        callId,
      ).timeout(const Duration(seconds: 6));
      return call.id == callId &&
          call.status == 'ringing' &&
          call.expiresAt.isAfter(clock);
    } catch (_) {
      return false;
    }
  }

  static Future<VoiceCall> _lookup(String callId) async {
    const storage = SecureStorage(FlutterSecureStorage());
    final api = VoiceCallApi(ApiClient(storage), independent: false);
    return (await api.get(callId)).call;
  }
}
