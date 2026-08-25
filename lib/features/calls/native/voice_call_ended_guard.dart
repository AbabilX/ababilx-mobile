import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cross-isolate memory for a call a terminal push already ended.
///
/// The "incoming" and "ended" pushes for one call travel independent
/// NATS → FCM hops with no ordering guarantee — a caller cancelling within a
/// couple of seconds can have "ended" land on the device before "incoming"
/// does. `VoiceCallNotifier._finishedCallIds` catches this reordering in the
/// foreground isolate, but `firebaseMessagingBackgroundHandler`
/// (`main.dart`) runs in a fresh isolate with no access to it — a
/// backgrounded or killed app would show the full-screen incoming call and
/// never learn it was cancelled, since nothing else re-delivers the ended
/// event. This durable guard is what lets the background isolate see it.
class VoiceCallEndedGuard {
  VoiceCallEndedGuard._();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'voice_call_ended_at_';
  // Comfortably past the ring timeout (60s) — an entry only needs to
  // outlive the window where its matching "incoming" push could still land.
  static const _ttl = Duration(seconds: 90);

  static Future<void> markEnded(String callId) async {
    if (callId.isEmpty) return;
    try {
      await _storage.write(
        key: '$_prefix$callId',
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  static Future<bool> wasEnded(String callId) async {
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
