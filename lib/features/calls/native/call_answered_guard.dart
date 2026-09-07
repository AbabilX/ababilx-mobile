import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cross-isolate note that THIS device is the one that answered a call.
///
/// One account can be signed in on several devices and every one of them
/// rings. When somebody picks up, the server has to tell the rest to stop —
/// but FCM addresses an account, never a device, so that message also lands on
/// the phone now holding the live call. Without this mark the answering device
/// would tear down the call it had just answered, and the background isolate,
/// which holds none of the call providers' state, has no other way to tell the
/// two cases apart.
///
/// Shared by both call systems: a DM call id and a group call id are both
/// UUIDs and never collide.
class CallAnsweredGuard {
  CallAnsweredGuard._();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'call_answered_here_at_';
  // Only has to outlive the window in which a "stop ringing" message for this
  // call could still arrive; the server gives those a 60s TTL.
  static const _ttl = Duration(seconds: 90);

  static Future<void> mark(String callId) async {
    if (callId.isEmpty) return;
    try {
      await _storage.write(
        key: '$_prefix$callId',
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  static Future<bool> answeredHere(String callId) async {
    if (callId.isEmpty) return false;
    try {
      final raw = await _storage.read(key: '$_prefix$callId');
      if (raw == null) return false;
      final at = DateTime.tryParse(raw);
      if (at == null || DateTime.now().toUtc().difference(at) > _ttl) {
        await _storage.delete(key: '$_prefix$callId');
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
