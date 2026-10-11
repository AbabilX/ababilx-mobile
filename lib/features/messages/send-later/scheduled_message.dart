import '../data/models/chat_models.dart';

/// A message waiting on the server to be sent at [sendAt] (server 0171).
///
/// [request] is the send body exactly as this account posted it — sealed,
/// for an encrypted chat. [opened] is that body read on this device, for the
/// list; null when it could not be opened (a locked vault, a key this phone
/// does not hold).
class ScheduledMessage {
  const ScheduledMessage({
    required this.id,
    required this.conversationId,
    required this.clientMessageId,
    required this.sendAt,
    required this.status,
    required this.failReason,
    required this.request,
    this.opened,
  });

  final String id;
  final String conversationId;
  final String clientMessageId;
  final DateTime sendAt;
  final String status;
  final String failReason;
  final Map<String, dynamic> request;
  final ChatMessage? opened;

  bool get failed => status == 'failed';

  /// Sealed under a key somebody in the chat can no longer read. Only one of
  /// the sender's own devices can seal it again; see `scheduled_reseal.dart`.
  bool get needsReseal => status == 'needs_rekey';

  String? get parentId {
    final id = request['parent_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  bool get isTask => request['task'] is Map;

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) {
    final request = json['message'];
    return ScheduledMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      clientMessageId: json['client_message_id'] as String? ?? '',
      sendAt:
          DateTime.tryParse(json['send_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      failReason: json['fail_reason'] as String? ?? '',
      request: request is Map
          ? Map<String, dynamic>.from(request)
          : const <String, dynamic>{},
    );
  }

  ScheduledMessage withOpened(ChatMessage message) => ScheduledMessage(
    id: id,
    conversationId: conversationId,
    clientMessageId: clientMessageId,
    sendAt: sendAt,
    status: status,
    failReason: failReason,
    request: request,
    opened: message,
  );

  /// The stored request as a message the vault can open: the same fields a
  /// sent message carries, with each encrypted file's key version taken from
  /// the body's — the server stamps exactly that on the row when it sends.
  ChatMessage asSealedMessage(String senderId) {
    final keyVersion = request['encryption_key_version'];
    return ChatMessage.fromJson({
      ...request,
      'id': id,
      'conversation_id': conversationId,
      'user_id': senderId,
      'created_at': sendAt.toUtc().toIso8601String(),
      'attachments': [
        for (final a in request['attachments'] as List? ?? const [])
          if (a is Map)
            {
              ...Map<String, dynamic>.from(a),
              'uploaded_by': senderId,
              if (a['enc_meta'] is String) 'enc_key_version': keyVersion,
            },
      ],
    });
  }
}
