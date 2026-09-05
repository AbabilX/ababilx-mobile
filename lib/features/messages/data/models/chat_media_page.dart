import 'package:equatable/equatable.dart';

import 'chat_attachment.dart';

/// One page of a conversation's shared files, newest first.
///
/// The server pages by MESSAGE rather than by attachment, so an album always
/// arrives whole and [nextCursor] never lands inside one.
class ChatMediaPage extends Equatable {
  const ChatMediaPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  const ChatMediaPage.empty()
    : items = const [],
      nextCursor = '',
      hasMore = false;

  final List<ChatMessageAttachment> items;
  final String nextCursor;
  final bool hasMore;

  factory ChatMediaPage.fromJson(Map<String, dynamic> json) => ChatMediaPage(
    items: (json['items'] as List? ?? [])
        .map((e) => ChatMessageAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: json['next_cursor'] as String? ?? '',
    hasMore: json['has_more'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [items, nextCursor, hasMore];
}
