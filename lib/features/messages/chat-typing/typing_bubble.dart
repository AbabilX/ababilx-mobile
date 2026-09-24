import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/typing-indicators/typing_indicators_provider.dart';
import '../chat-select/selectable_message_row.dart';
import '../chat-timeline/message_bubble.dart';
import '../chat-timeline/signal_bubble_metrics.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'chat_typing_provider.dart';
import 'typing_avatars.dart';
import 'typing_thought.dart';

/// Typing indicator at the newest end of the timeline, in a DM and in a
/// group. The header still says "typing…" / "Alice is typing…"; this bumps an
/// animated thought-bubble icon ([HugeIcons.strokeRoundedThoughtBubble]) in.
/// A group also has to say WHO, so the typists' faces sit in the avatar
/// gutter an incoming group message uses.
///
/// [MessageList] reserves the slot only where [typingBubbleSlot] says so.
class ChatTypingBubble extends ConsumerWidget {
  const ChatTypingBubble({
    super.key,
    required this.conversationId,
    required this.messages,
  });

  final String conversationId;

  /// The timeline's messages, newest last — where a group typist's picture
  /// comes from.
  final List<ChatMessage> messages;

  static const _bump = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(typingIndicatorsProvider);
    final typists = ref.watch(
      chatTypingProvider.select((m) => m[conversationId]),
    );
    final visible = enabled && typists != null && typists.isNotEmpty;
    final isGroup = ref.watch(
      chatProvider.select(
        (c) => c.conversationById(conversationId)?.hasDmPeer != true,
      ),
    );
    final scheme = Theme.of(context).colorScheme;
    final hasWallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(conversationId)
        .isSet;
    final colors = SignalBubbleColors.of(scheme, hasWallpaper: hasWallpaper);

    // Keep the slot mounted so AnimatedSize can bump height in and out.
    return AnimatedSize(
      duration: _bump,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                SelectableMessageRow.restingGutter,
                SignalBubbleMetrics.spacingDefault,
                SelectableMessageRow.restingGutter,
                4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isGroup) ...[
                    TypingAvatars(
                      typists: typists,
                      messages: messages,
                      ring: scheme.surface,
                    ),
                    const SizedBox(width: 8),
                  ],
                  TypingThoughtIcon(color: colors.muted),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Whether this conversation reserves a typing slot in the list: a DM with a
/// real peer, or a group. Never a feed (nobody there types) or Note to Self.
bool typingBubbleSlot(WidgetRef ref, String conversationId) {
  final conversation = ref.watch(
    chatProvider.select((c) => c.conversationById(conversationId)),
  );
  if (conversation == null) return false;
  return conversation.hasDmPeer ||
      conversation.isGroup ||
      conversation.isChannel;
}
