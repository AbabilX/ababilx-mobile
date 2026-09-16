import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import 'message_bubble.dart';
import 'message_delivery_status.dart';
import 'signal_bubble_metrics.dart';

/// Time and delivery state, inside the bubble on its last line — where Signal
/// puts them, rather than on a row of their own below the message.
///
/// [onMedia] is a picture/video bubble: the row sits on the image, so it
/// takes a light overlay colour instead of the bubble's muted foreground,
/// and drops the gap that a text footer needs above itself.
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
  });

  final ChatMessage message;
  final SignalBubbleColors colors;
  final bool isOwn;
  final bool isSending;
  final bool isFailed;
  final Animation<double> pulse;
  final bool onMedia;

  /// Same exception as the lightbox caption and details banner chrome: the
  /// photo is not a themed surface, so the overlay has to pick its own ink.
  static const _onMediaInk = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final percent = ((message.uploadProgress ?? 0) * 100).round();
    final label = isFailed
        ? tr('chat_tap_to_retry')
        : message.sendStatus == MessageSendStatus.uploading
        ? '${tr('chat_uploading')} $percent%'
        : isSending
        ? tr('chat_sending')
        : formatChatTime(message.createdAt);
    final ink = onMedia ? _onMediaInk : colors.muted;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: SignalBubbleMetrics.footerTextSize,
            height: 1.1,
            color: isFailed ? error : ink,
            fontWeight: isFailed ? FontWeight.w500 : FontWeight.normal,
            // Readable on a photo without a scrim behind the row.
            shadows: onMedia
                ? const [Shadow(blurRadius: 6, color: Color(0xCC000000))]
                : null,
          ),
        ),
        if (isOwn && !isFailed) ...[
          const SizedBox(width: 4),
          MessageDeliveryStatus(
            status: message.sendStatus,
            pulse: pulse,
            delivery: message.delivery,
            color: ink,
          ),
        ],
      ],
    );
    if (onMedia) return row;
    return Padding(padding: const EdgeInsets.only(top: 2), child: row);
  }
}
