import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/typing-indicators/typing_indicators_provider.dart';
import '../chat-select/selectable_message_row.dart';
import '../chat-timeline/message_bubble.dart';
import '../chat-timeline/signal_bubble_metrics.dart';
import '../providers/chat_provider.dart';
import '../wallpaper/chat_wallpaper_provider.dart';
import 'chat_typing_provider.dart';
import 'typing_thought.dart';

/// DM-only typing indicator at the newest end of the timeline.
///
/// The header still shows "typing…"; this bumps an animated thought-bubble
/// icon ([HugeIcons.strokeRoundedThoughtBubble]) when the peer types. Groups
/// keep the header only for now.
///
/// Mount only inside a DM (`hasDmPeer`); [MessageList] gates the slot.
class DmTypingBubble extends ConsumerWidget {
  const DmTypingBubble({super.key, required this.conversationId});

  final String conversationId;

  static const _bump = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(typingIndicatorsProvider);
    final typists = ref.watch(
      chatTypingProvider.select((m) => m[conversationId]),
    );
    final visible = enabled && typists != null && typists.isNotEmpty;
    final hasWallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(conversationId)
        .isSet;
    final colors = SignalBubbleColors.of(
      Theme.of(context).colorScheme,
      hasWallpaper: hasWallpaper,
    );

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
              child: Align(
                alignment: Alignment.centerLeft,
                child: TypingThoughtIcon(color: colors.muted),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Whether this conversation should reserve a typing-bubble slot in the list.
bool dmTypingBubbleSlot(WidgetRef ref, String conversationId) {
  final conversation = ref.watch(
    chatProvider.select((c) => c.conversationById(conversationId)),
  );
  return conversation?.hasDmPeer == true;
}
