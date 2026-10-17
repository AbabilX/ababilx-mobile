import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// One place the account is signed in — a browser, the desktop app, or a phone.
/// Survives token rotation, so it maps to a real device the user can recognise
/// and revoke. Mirrors models.UserSession on the backend.
class UserSession {
  const UserSession({
    required this.id,
    required this.client,
    required this.origin,
    required this.label,
    required this.ip,
    required this.createdAt,
    required this.lastSeenAt,
    required this.current,
    this.linked = false,
  });

  final String id;

  /// web | desktop | mobile | unknown
  final String client;

  /// How the sign-in happened: github | google | qr | desktop_code | legacy
  final String origin;

  /// The user-chosen or client-sent device name, else derived from the user agent.
  final String label;
  final String ip;
  final String createdAt;
  final String lastSeenAt;

  /// This app's own session. Never offered a plain revoke — only Sign Out.
  final bool current;

  /// A web or desktop sign-in that keeps its own copy of the chats (server
  /// 0174). Signing it out also unlinks it.
  final bool linked;

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    id: json['id'] as String? ?? '',
    client: json['client'] as String? ?? '',
    origin: json['origin'] as String? ?? '',
    label: json['label'] as String? ?? '',
    ip: json['ip'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    lastSeenAt: json['last_seen_at'] as String? ?? '',
    current: json['current'] as bool? ?? false,
    linked: json['linked'] as bool? ?? false,
  );

  UserSession withLabel(String next) => UserSession(
    id: id,
    client: client,
    origin: origin,
    label: next,
    ip: ip,
    createdAt: createdAt,
    lastSeenAt: lastSeenAt,
    current: current,
    linked: linked,
  );
}

class SessionRepository {
  const SessionRepository(this._client);
  final ApiClient _client;

  Future<List<UserSession>> list() async {
    final res = await _client.get(ApiConstants.meSessions);
    final data = (res.data as Map<String, dynamic>)['data'];
    final raw = (data as Map<String, dynamic>?)?['sessions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => UserSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Names one device. An empty name clears the override, and the server
  /// answers with the label it fell back to, so the app never re-derives it.
  Future<String> rename(String id, String deviceName) async {
    final res = await _client.patch(
      '${ApiConstants.meSessions}/$id',
      data: {'device_name': deviceName},
    );
    final data = (res.data as Map<String, dynamic>)['data'];
    return (data as Map<String, dynamic>?)?['label'] as String? ?? deviceName;
  }

  Future<void> revoke(String id) =>
      _client.delete('${ApiConstants.meSessions}/$id');

  /// Signs every other device out. Returns how many were ended.
  Future<int> revokeOthers() async {
    final res = await _client.post(ApiConstants.meSessionsRevokeOthers);
    final data = (res.data as Map<String, dynamic>)['data'];
    return (data as Map<String, dynamic>?)?['revoked'] as int? ?? 0;
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(apiClientProvider)),
);
