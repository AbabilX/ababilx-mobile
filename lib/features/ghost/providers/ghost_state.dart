import 'dart:typed_data';

import '../data/ghost_session.dart';
import '../protocol/ghost_item_rules.dart';

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
    this.rules = GhostItemRules.none,
    this.expired = false,
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

  /// What the sender allows: a view timer (photos) and saving.
  final GhostItemRules rules;

  /// A timed photo that was viewed: its bytes are zeroed on both phones and
  /// only the placeholder is left.
  final bool expired;

  bool get isFile => fileName != null;
  bool get isImage => (mime ?? '').startsWith('image/');
  bool get isPdf =>
      mime == 'application/pdf' ||
      (fileName ?? '').toLowerCase().endsWith('.pdf');
  bool get isVideo => (mime ?? '').startsWith('video/');
  bool get timed => isImage && rules.timer.timed;

  /// The receiver may hand this to another app or save it. The sender's own
  /// copy is always theirs.
  bool get mayLeaveApp => fromMe || rules.allowSave;
  bool get complete => !isFile || (bytes != null && transferred >= size);
  double get progress => size == 0 ? 1 : (transferred / size).clamp(0, 1);

  GhostItem copyWith({
    Uint8List? bytes,
    int? transferred,
    bool? failed,
    bool? expired,
  }) => GhostItem(
    id: id,
    fromMe: fromMe,
    at: at,
    body: body,
    fileName: fileName,
    mime: mime,
    size: size,
    bytes: expired == true ? null : bytes ?? this.bytes,
    transferred: transferred ?? this.transferred,
    failed: failed ?? this.failed,
    rules: rules,
    expired: expired ?? this.expired,
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
    this.lastRules = GhostItemRules.none,
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

  /// The sender's last choice in the send preview, offered again for the next
  /// one. Session-only: a new Ghost Chat starts back at no timer, no saving.
  final GhostItemRules lastRules;

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
    GhostItemRules? lastRules,
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
    lastRules: lastRules ?? this.lastRules,
  );
}
