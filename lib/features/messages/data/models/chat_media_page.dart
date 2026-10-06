import 'package:equatable/equatable.dart';

import '../../../khaam/data/khaam_payload.dart';
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
        // A Khaam's photo belongs to its card, not to the chat's media.
        .where((a) => !isKhaamPhotoFile(a.fileName))
        .toList(),
    nextCursor: json['next_cursor'] as String? ?? '',
    hasMore: json['has_more'] as bool? ?? false,
  );

  /// This page with [opened] in place of its items — an encrypted file's
  /// real name is only known once its key is opened, so the Khaam filter
  /// runs again here.
  ChatMediaPage withItems(List<ChatMessageAttachment> opened) => ChatMediaPage(
    items: [
      for (final a in opened)
        if (!isKhaamPhotoFile(a.fileName)) a,
    ],
    nextCursor: nextCursor,
    hasMore: hasMore,
  );

  @override
  List<Object?> get props => [items, nextCursor, hasMore];
}
