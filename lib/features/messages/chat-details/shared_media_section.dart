import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../chat-media/shared_media_thumb.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_details_provider.dart';

/// Signal's "Shared media": a strip of the newest files in this conversation
/// and a way into all of them.
///
/// The block disappears when the conversation has no files rather than showing
/// an empty state — a heading over nothing is a row that only ever says "no".
class SharedMediaSection extends ConsumerWidget {
  const SharedMediaSection({super.key, required this.conversationId});

  final String conversationId;

  static const double _thumb = 84;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(chatSharedMediaProvider(conversationId)).valueOrNull?.items ??
        const <ChatMessageAttachment>[];
    if (items.isEmpty) return const SizedBox.shrink();
    // Videos open their own player, so the swipe gallery holds pictures only.
    final gallery = items.where((a) => a.isImage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Shared media',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: _thumb,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => SharedMediaThumb(
              attachment: items[i],
              gallery: gallery,
              size: _thumb,
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text(
            'See all',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          onTap: () => context.push('/messages/$conversationId/media'),
        ),
      ],
    );
  }
}
