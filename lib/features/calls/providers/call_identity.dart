import '../voice_call_log.dart';

/// Which account this device is on a call the server just returned.
///
/// [serverId] is the call row's own answer — the caller of a call this device
/// started, the callee of one it accepted — and it wins: the server
/// authenticated the request, so it cannot be wrong about who made it.
/// [known] (the profile's id) is only the fallback for a row that does not
/// say. Relying on the profile alone is how a fresh install, whose first
/// profile load had failed, came to believe it had not placed its own call.
String callIdentity(String known, String serverId, {required String source}) {
  if (serverId.isEmpty) return known;
  if (known != serverId) {
    voiceCallLog(
      'identity.from_call',
      source: source,
      reason: known.isEmpty ? 'profile_empty' : 'profile_differs',
    );
  }
  return serverId;
}
