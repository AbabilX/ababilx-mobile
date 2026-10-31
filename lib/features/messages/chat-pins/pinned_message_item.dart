import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-timeline/message_row_content.dart';
import '../chat-timeline/bubble_metrics.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';

/// One pin drawn as the chat draws it — the timeline's own bubble, sender name
/// and reactions — with Telegram's round "go to" arrow on the open side.
/// Tapping either jumps; a long press offers Go to / Unpin (Unpin only when
/// [onUnpin] is set — a member cannot take down the group's shared pin).
class PinnedMessageItem extends ConsumerWidget {
  const PinnedMessageItem({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isGroup,
    required this.hasWallpaper,
    required this.onOpen,
    required this.onUnpin,
    this.pinnedForEveryone = false,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool isGroup;
  final bool hasWallpaper;
  final VoidCallback onOpen;
  final VoidCallback? onUnpin;
  final bool pinnedForEveryone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bubble = Flexible(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        onLongPress: () => _showActions(context, ref),
        child: Column(
          crossAxisAlignment: isOwn
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (pinnedForEveryone) const _EveryoneTag(),
            MessageRowContent(
              message: message,
              pulse: kAlwaysCompleteAnimation,
              isSending: false,
              isFailed: false,
              isOwnMessage: isOwn,
              isGroup: isGroup,
              hasWallpaper: hasWallpaper,
            ),
          ],
        ),
      ),
    );
    final jump = _JumpButton(
      tooltip: AppTranslations.translate(context, ref, 'chat_go_to_message'),
      onTap: onOpen,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BubbleMetrics.listSideGutter,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isOwn
            ? [jump, const SizedBox(width: 8), bubble]
            : [bubble, const SizedBox(width: 8), jump],
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedArrowRight02),
              title: Text(tr('chat_go_to_message')),
              onTap: () => Navigator.of(sheet).pop(onOpen),
            ),
            if (onUnpin != null)
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedPinOff),
                title: Text(tr('chat_unpin_message')),
                onTap: () => Navigator.of(sheet).pop(onUnpin),
              ),
          ],
        ),
      ),
    );
    action?.call();
  }
}

/// "Pinned for everyone" over a group's shared pin, so it reads apart from
/// the caller's own.
class _EveryoneTag extends ConsumerWidget {
  const _EveryoneTag();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatIcon(
                HugeIcons.strokeRoundedMegaphone01,
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                AppTranslations.translate(
                  context,
                  ref,
                  'group_pin_for_everyone',
                ),
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 36,
            child: Center(
              child: ChatIcon(
                HugeIcons.strokeRoundedArrowRight02,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
