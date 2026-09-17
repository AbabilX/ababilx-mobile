import 'dart:typed_data';

import '../data/ghost_session.dart';

/// Where this phone is in a Ghost Chat.
///
/// ```
/// idle ─invite─▶ inviting ─accepted─▶ connecting ─open─▶ live ⇄ reconnecting
/// idle ─ghost.invite─▶ invited ─join─▶ accepting ─▶ connecting ─▶ live
/// any ─burn/leave/lost/declined/no answer─▶ ended ─close─▶ idle
/// ```
enum GhostPhase {
  idle,
  inviting,
  invited,
  accepting,
  connecting,
  live,
  reconnecting,
  ended,
}

/// Local end reasons the server never records: nobody answered, or this phone
/// could not even begin.
abstract final class GhostLocalReason {
  static const noAnswer = 'no_answer';
  static const failed = 'failed';
}

/// One message or file. Lives in RAM only; the burn zeroes [bytes].
class GhostItem {
  const GhostItem({
    required this.id,
    required this.fromMe,
    required this.at,
    this.body,
    this.fileName,
    this.mime,
    this.size = 0,
    this.bytes,
    this.transferred = 0,
    this.failed = false,
  });

  final String id;
  final bool fromMe;
  final DateTime at;
  final String? body;
  final String? fileName;
  final String? mime;
  final int size;
  final Uint8List? bytes;
  final int transferred;
  final bool failed;

  bool get isFile => fileName != null;
  bool get isImage => (mime ?? '').startsWith('image/');
  bool get complete => !isFile || (bytes != null && transferred >= size);
  double get progress => size == 0 ? 1 : (transferred / size).clamp(0, 1);

  GhostItem copyWith({Uint8List? bytes, int? transferred, bool? failed}) =>
      GhostItem(
        id: id,
        fromMe: fromMe,
        at: at,
        body: body,
        fileName: fileName,
        mime: mime,
        size: size,
        bytes: bytes ?? this.bytes,
        transferred: transferred ?? this.transferred,
        failed: failed ?? this.failed,
      );
}

class GhostState {
  const GhostState({
    this.phase = GhostPhase.idle,
    this.session,
    this.conversationId = '',
    this.peerName = '',
    this.peerAvatarUrl,
    this.items = const [],
    this.peerTyping = false,
    this.endReason,
    this.endedByMe = false,
    this.error,
  });

  final GhostPhase phase;
  final GhostSession? session;
  final String conversationId;
  final String peerName;
  final String? peerAvatarUrl;
  final List<GhostItem> items;
  final bool peerTyping;
  final String? endReason;
  final bool endedByMe;

  /// A refusal to show once (start failed, file too large), as a stable code.
  final String? error;

  bool get inSession => phase != GhostPhase.idle && phase != GhostPhase.ended;
  bool get canSend => phase == GhostPhase.live;

  GhostState copyWith({
    GhostPhase? phase,
    GhostSession? session,
    String? conversationId,
    String? peerName,
    String? peerAvatarUrl,
    List<GhostItem>? items,
    bool? peerTyping,
    String? endReason,
    bool? endedByMe,
    String? error,
    bool clearError = false,
  }) => GhostState(
    phase: phase ?? this.phase,
    session: session ?? this.session,
    conversationId: conversationId ?? this.conversationId,
    peerName: peerName ?? this.peerName,
    peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
    items: items ?? this.items,
    peerTyping: peerTyping ?? this.peerTyping,
    endReason: endReason ?? this.endReason,
    endedByMe: endedByMe ?? this.endedByMe,
    error: clearError ? null : (error ?? this.error),
  );
}
