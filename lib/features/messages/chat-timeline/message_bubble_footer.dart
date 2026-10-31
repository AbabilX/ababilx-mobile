import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../dm-settings/receipts/receipts_hidden_provider.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import 'message_bubble.dart';
import 'message_delivery_status.dart';
import 'message_seen.dart';
import 'bubble_metrics.dart';

/// Time and delivery state, inside the bubble on its last line — where the
/// reference app puts them, rather than on a row of their own below the
/// message.
///
/// [onMedia] is a picture/video bubble: the row sits on the image, so it
/// takes a light overlay colour instead of the bubble's muted foreground,
/// and drops the gap that a text footer needs above itself.
///
/// [onClear] is a sticker or GIF with no bubble behind it: white on the
/// chat's own background is unreadable in a light theme, so the row gets a
/// small pill of the bubble's fill and its ordinary muted ink.
class MessageBubbleFooter extends ConsumerWidget {
  const MessageBubbleFooter({
    super.key,
    required this.message,
    required this.colors,
    required this.isOwn,
    required this.isSending,
    required this.isFailed,
    required this.pulse,
    this.onMedia = false,
    this.onClear = false,
  });

  final ChatMessage message;
  final BubbleColors colors;
  final bool isOwn;
  final bool isSending;
  final bool isFailed;
  final Animation<double> pulse;
  final bool onMedia;
  final bool onClear;

  /// Same exception as the lightbox caption and details banner chrome: the
  /// photo is not a themed surface, so the overlay has to pick its own ink.
  static const _onMediaInk = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    String tr(String key) => AppTranslations.translate(context, ref, key);
    // To a private peer (server 0152), or in a DM where somebody hid ticks
    // (0159), nothing about delivery is shown — no clock, no tick, no
    // "Sending…". A failure still says so: that is about this phone.
    final hideTicks =
        isOwn &&
        ref.watch(conversationTicksHiddenProvider(message.conversationId));
    // Upload progress is the ring on the preview. The footer keeps the time.
    final label = isFailed
        ? tr('chat_tap_to_retry')
        : isSending &&
              !hideTicks &&
              message.sendStatus != MessageSendStatus.uploading
        ? tr('chat_sending')
        : formatChatTime(message.createdAt);
    final shadowed = onMedia && !onClear;
    final ink = shadowed ? _onMediaInk : colors.muted;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: BubbleMetrics.footerTextSize,
            height: 1.1,
            color: isFailed ? error : ink,
            fontWeight: isFailed ? FontWeight.w500 : FontWeight.normal,
            // Readable on a photo without a scrim behind the row.
            shadows: shadowed
                ? const [Shadow(blurRadius: 6, color: Color(0xCC000000))]
                : null,
          ),
        ),
        if (isOwn && !isFailed && !hideTicks) ...[
          const SizedBox(width: 4),
          MessageDeliveryStatus(
            status: message.sendStatus,
            pulse: pulse,
            delivery: message.delivery,
            color: ink,
            seen: seenByReadTime(
              message.createdAt,
              ref.watch(othersReadAtProvider(message.conversationId)),
            ),
          ),
        ],
      ],
    );
    if (onClear) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: row,
        ),
      );
    }
    if (onMedia) return row;
    return Padding(padding: const EdgeInsets.only(top: 2), child: row);
  }
}
