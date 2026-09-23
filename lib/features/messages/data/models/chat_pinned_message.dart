import 'chat_message.dart';

/// One of the caller's own pins: private to them, newest first on the server.
class ChatPinnedMessage {
  const ChatPinnedMessage({required this.message, required this.pinnedAt});

  final ChatMessage message;
  final String pinnedAt;

  factory ChatPinnedMessage.fromJson(Map<String, dynamic> json) =>
      ChatPinnedMessage(
        message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
        pinnedAt: json['pinned_at'] as String? ?? '',
      );

  ChatPinnedMessage withMessage(ChatMessage next) =>
      ChatPinnedMessage(message: next, pinnedAt: pinnedAt);
}
