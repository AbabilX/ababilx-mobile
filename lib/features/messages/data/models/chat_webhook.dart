import 'package:equatable/equatable.dart';

/// One inbound feed endpoint, without its secret.
///
/// The raw token is never stored and never returned again: it exists in a
/// single response, at creation and at regeneration, and lives in
/// [ChatWebhookCreated] alone.
class ChatWebhook extends Equatable {
  const ChatWebhook({
    required this.id,
    required this.conversationId,
    required this.name,
    this.avatarUrl,
    this.createdBy,
    required this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final String conversationId;
  final String name;
  final String? avatarUrl;
  final String? createdBy;
  final String createdAt;
  final String? lastUsedAt;

  factory ChatWebhook.fromJson(Map<String, dynamic> json) => ChatWebhook(
    id: json['id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    name: json['name'] as String? ?? 'Webhook',
    avatarUrl: json['avatar_url'] as String?,
    createdBy: json['created_by'] as String?,
    createdAt: json['created_at'] as String? ?? '',
    lastUsedAt: json['last_used_at'] as String?,
  );

  @override
  List<Object?> get props => [id, conversationId, name, avatarUrl, lastUsedAt];
}

/// The one response that carries the secret URL. Show it, let it be copied,
/// and drop it — nothing on the device or the server can produce it again.
class ChatWebhookCreated extends Equatable {
  const ChatWebhookCreated({
    required this.webhook,
    required this.url,
    required this.token,
  });

  final ChatWebhook webhook;
  final String url;
  final String token;

  factory ChatWebhookCreated.fromJson(Map<String, dynamic> json) =>
      ChatWebhookCreated(
        webhook: ChatWebhook.fromJson(
          Map<String, dynamic>.from(json['webhook'] as Map? ?? const {}),
        ),
        url: json['url'] as String? ?? '',
        token: json['token'] as String? ?? '',
      );

  @override
  List<Object?> get props => [webhook, url];
}
