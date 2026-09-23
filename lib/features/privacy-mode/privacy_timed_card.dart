import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../ghost/protocol/ghost_item_rules.dart';
import '../ghost/widgets/ghost_labels.dart';
import '../messages/chat_icon.dart';
import '../messages/data/models/chat_models.dart';
import '../messages/providers/chat_provider.dart';
import 'privacy_timed_viewer.dart';

/// A timed or expired photo as the timeline shows it — never the picture.
///
/// Receiver, unopened: "Photo · 5 seconds / Tap to view". After that, and on
/// the sender's phone throughout: "Viewed" / "Opened" / "Not opened yet".
/// Expired: "Photo expired" on both. No thumbnail on purpose — a blurred
/// preview is still a copy that outlives the timer (Ghost Chat's rule).
class PrivacyTimedCard extends ConsumerWidget {
  const PrivacyTimedCard({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    String t(String key) => AppTranslations.translate(context, ref, key);
    final me = ref.watch(chatProvider.select((s) => s.currentUserId));
    final fromMe = attachment.uploadedBy == me;
    final local = ref.watch(openedTimedMediaProvider);
    final shown = local.shown.contains(attachment.id);
    final retry = local.retry.contains(attachment.id);
    final opened = shown || (attachment.viewedAt != null && !retry);
    // Not `fileUrl.isEmpty`: the server withholds a timed photo's URL from
    // every read, so an empty URL is the normal state of a live one.
    final expired = attachment.expired;
    final timer = GhostViewTimer.decode(
      attachment.viewSeconds == 0 ? 'once' : attachment.viewSeconds,
    );
    final canOpen = !fromMe && !expired && !shown && (!opened || retry);

    final title = expired
        ? t('chat_media_expired')
        : '${ghostText(ref, 'ghost_photo')} · ${ghostTimerLabel(ref, timer)}';
    final subtitle = expired
        ? null
        : fromMe
        ? (opened
              ? ghostText(ref, 'ghost_photo_opened')
              : t('chat_media_not_opened'))
        : opened
        ? ghostText(ref, 'ghost_photo_viewed')
        : ghostText(ref, 'ghost_tap_to_view');

    return InkWell(
      onTap: canOpen ? () => openTimedPhoto(context, ref, attachment) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(
              expired || opened
                  ? HugeIcons.strokeRoundedViewOff
                  : HugeIcons.strokeRoundedTimer02,
              color: canOpen ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontStyle: expired ? FontStyle.italic : null,
                      color: expired ? colors.onSurfaceVariant : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
