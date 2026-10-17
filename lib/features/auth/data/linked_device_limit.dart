import 'package:dio/dio.dart';

/// One web or desktop install that keeps its own copy of the chats (server
/// migration 0174, `models.LinkedDevice`). Signing out [sessionId] is what
/// unlinks it: revoking a sign-in revokes the chat devices bound to it.
class LinkedDeviceSummary {
  const LinkedDeviceSummary({
    required this.deviceId,
    required this.platform,
    required this.sessionId,
    required this.label,
    required this.linkedAt,
    required this.lastSeenAt,
  });

  final String deviceId;

  /// web | desktop
  final String platform;
  final String sessionId;
  final String label;
  final String linkedAt;
  final String lastSeenAt;

  factory LinkedDeviceSummary.fromJson(Map<String, dynamic> json) =>
      LinkedDeviceSummary(
        deviceId: json['device_id']?.toString() ?? '',
        platform: json['platform']?.toString() ?? '',
        sessionId: json['session_id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        linkedAt: json['linked_at']?.toString() ?? '',
        lastSeenAt: json['last_seen_at']?.toString() ?? '',
      );
}

/// The account already has as many linked devices as the server allows
/// (409 `linked_device_limit`). The one-scan approval is refused before
/// anything is approved, so the same code can be approved again once one of
/// [devices] is signed out.
class LinkedDeviceLimit implements Exception {
  const LinkedDeviceLimit({required this.limit, required this.devices});

  final int limit;
  final List<LinkedDeviceSummary> devices;

  /// That refusal read off [error], or null for any other failure.
  static LinkedDeviceLimit? from(Object error) {
    if (error is! DioException || error.response?.statusCode != 409) {
      return null;
    }
    final body = error.response?.data;
    if (body is! Map || body['error'] != 'linked_device_limit') return null;
    final data = body['data'] is Map ? body['data'] as Map : const {};
    final raw = data['devices'] is List ? data['devices'] as List : const [];
    return LinkedDeviceLimit(
      limit: (data['limit'] as num?)?.toInt() ?? 5,
      devices: [
        for (final row in raw.whereType<Map>())
          LinkedDeviceSummary.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}
