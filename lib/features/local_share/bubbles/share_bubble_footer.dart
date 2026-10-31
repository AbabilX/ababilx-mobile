import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../messages/chat-timeline/message_bubble.dart' show BubbleColors;
import '../../messages/chat-timeline/bubble_metrics.dart';
import '../../messages/chat_icon.dart';
import '../engine/store/share_records.dart';
import '../share_text.dart';

/// Time, and for our own bubbles where the message stands. A failed one says
/// so in words and is tappable — a red glyph alone does not say what to do.
class ShareBubbleFooter extends ConsumerWidget {
  const ShareBubbleFooter({
    super.key,
    required this.message,
    required this.colors,
    required this.onRetry,
  });

  final ShareMessageRecord message;
  final BubbleColors colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = TextStyle(
      fontSize: BubbleMetrics.footerTextSize,
      color: colors.muted,
    );
    final time = DateFormat.jm().format(
      DateTime.fromMillisecondsSinceEpoch(message.sentAt),
    );
    final status = message.status;
    if (status == ShareMessageStatus.failed && message.fromMe) {
      final error = Theme.of(context).colorScheme.error;
      return InkWell(
        onTap: onRetry,
        child: Text(
          lsText(ref, 'ls_failed_retry'),
          style: style.copyWith(color: error, fontWeight: FontWeight.w600),
        ),
      );
    }
    final label = switch (status) {
      ShareMessageStatus.canceled => lsText(ref, 'ls_canceled'),
      ShareMessageStatus.failed => lsText(ref, 'ls_failed'),
      _ => null,
    };
    final glyph = !message.fromMe
        ? null
        : switch (status) {
            ShareMessageStatus.sending => HugeIcons.strokeRoundedClock01,
            ShareMessageStatus.done => HugeIcons.strokeRoundedTick02,
            _ => null,
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label == null ? time : '$label · $time', style: style),
        if (glyph != null) ...[
          const SizedBox(width: 4),
          ChatIcon(glyph, size: 14, color: colors.muted),
        ],
      ],
    );
  }
}
