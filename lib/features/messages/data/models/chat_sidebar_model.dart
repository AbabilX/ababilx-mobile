import 'package:equatable/equatable.dart';

import 'chat_conversation.dart';

class ChatSidebar extends Equatable {
  const ChatSidebar({this.channels = const [], this.dms = const []});

  final List<ChatConversation> channels;
  final List<ChatConversation> dms;

  factory ChatSidebar.fromJson(Map<String, dynamic> json) => ChatSidebar(
        channels: (json['channels'] as List<dynamic>? ?? [])
            .map((e) => ChatConversation.fromJson(e as Map<String, dynamic>))
            .toList(),
        dms: (json['dms'] as List<dynamic>? ?? [])
            .map((e) => ChatConversation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [channels, dms];
}
