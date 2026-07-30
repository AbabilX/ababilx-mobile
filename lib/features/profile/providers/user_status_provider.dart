import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/ws_client.dart';

/// One team member's Slack-style custom status.
class UserStatus {
  const UserStatus({required this.emoji, required this.text, this.expiresAt});

  final String emoji;
  final String text;
  final DateTime? expiresAt;

  bool get isActive =>
      text.isNotEmpty &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

/// Team-wide map of userId → active custom status, kept in sync over the WS
/// connection (mirrors [InCallPresenceNotifier]).
class UserStatusNotifier extends Notifier<Map<String, UserStatus>> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _booted = false;

  @override
  Map<String, UserStatus> build() {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _sub = null;
      _booted = false;
    });
    return {};
  }

  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;
    final ws = ref.read(wsClientProvider);
    _sub = ws.events.listen(_onEvent);
    await ws.connect();
  }

  UserStatus? statusFor(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return state[userId];
  }

  /// Optimistic local update right after a successful set/clear API call, so
  /// the UI doesn't wait for the WS echo.
  void setLocal(String userId, UserStatus? status) {
    final next = Map<String, UserStatus>.from(state);
    if (status == null || !status.isActive) {
      next.remove(userId);
    } else {
      next[userId] = status;
    }
    state = next;
  }

  void clear() => state = {};

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (type == 'user.status.snapshot') {
      final raw = event['user_statuses'];
      if (raw is! List) {
        state = {};
        return;
      }
      final next = <String, UserStatus>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final entry = _parse(Map<String, dynamic>.from(item));
        if (entry != null) next[entry.key] = entry.value;
      }
      state = next;
      return;
    }
    if (type != 'user.status') return;
    final payload = event['user_status'];
    if (payload is! Map) return;
    final entry = _parse(Map<String, dynamic>.from(payload));
    final userId = payload['user_id'] as String? ?? '';
    if (userId.isEmpty) return;
    final next = Map<String, UserStatus>.from(state);
    if (entry == null) {
      next.remove(userId);
    } else {
      next[userId] = entry.value;
    }
    state = next;
  }

  MapEntry<String, UserStatus>? _parse(Map<String, dynamic> json) {
    final userId = json['user_id'] as String? ?? '';
    final text = (json['text'] as String? ?? '').trim();
    if (userId.isEmpty || text.isEmpty) return null;
    final expiresRaw = json['expires_at'] as String?;
    final expiresAt = expiresRaw != null && expiresRaw.isNotEmpty
        ? DateTime.tryParse(expiresRaw)?.toLocal()
        : null;
    final status = UserStatus(
      emoji: json['emoji'] as String? ?? '',
      text: text,
      expiresAt: expiresAt,
    );
    if (!status.isActive) return null;
    return MapEntry(userId, status);
  }
}

final userStatusProvider =
    NotifierProvider<UserStatusNotifier, Map<String, UserStatus>>(
      UserStatusNotifier.new,
    );

final userStatusForProvider = Provider.family<UserStatus?, String?>((
  ref,
  userId,
) {
  if (userId == null || userId.isEmpty) return null;
  return ref.watch(userStatusProvider)[userId];
});
