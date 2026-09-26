import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-select/message_selection.dart';
import '../../messages/chat_icon.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/khaam_covers.dart';
import '../data/khaam_payload.dart';
import '../data/khaam_status.dart';
import '../providers/khaam_providers.dart';
import '../screens/khaam_open_route.dart';
import 'khaam_cover_band.dart';
import 'khaam_foil_painter.dart';

/// A Khaam in the timeline. Fills the bubble edge to edge, like media; the
/// bubble's own footer (time, ticks) sits under it.
///
/// The receiver sees the cover and a strip of foil until they scratch the
/// card open — the message is never printed here before that.
class KhaamBubbleCard extends ConsumerWidget {
  const KhaamBubbleCard({
    super.key,
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  static const width = 232.0;

  final ChatMessage message;
  final KhaamPayload payload;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final cover = khaamCoverById(payload.coverId);
    final opened = khaamIsOpened(
      ref.watch(khaamOpenedIdsProvider).valueOrNull,
      payload.id,
    );
    final selecting = ref.watch(messageSelectionProvider).isActive;
    final failed = message.sendStatus == MessageSendStatus.failed;
    final state = khaamStatus(isOwn: isOwn, opened: opened);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = payload.message.trim();

    final status = switch (state) {
      KhaamStatus.sent => t('khaam_sent'),
      KhaamStatus.opened => t('khaam_opened'),
      KhaamStatus.unopened => t('khaam_tap_to_open'),
    };

    final card = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KhaamCoverBand(
            cover: cover,
            width: width,
            height: 112,
            child: Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(
                t(cover.nameKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
                ),
              ),
            ),
          ),
          Container(
            color: colors.surfaceContainerLowest,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: state == KhaamStatus.unopened
                ? KhaamFoilStrip(cover: cover, hint: t('khaam_scratch_hint'))
                : Text(
                    text.isEmpty ? t(cover.nameKey) : text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
          ),
          Container(
            color: colors.surfaceContainerLowest,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedMailLove01,
                  size: 14,
                  color: cover.flap,
                ),
                const SizedBox(width: 6),
                Text(
                  t('khaam_chip'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: state == KhaamStatus.unopened
                        ? cover.flap
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // While picking rows, or when the send failed, the row's own tap wins:
    // selecting toggles, a failed bubble retries.
    if (selecting || failed || message.isPending) return card;
    return Semantics(
      button: true,
      label: '${payload.fallbackText}. $status',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openKhaam(
          context,
          message: message,
          payload: payload,
          isOwn: isOwn,
        ),
        child: card,
      ),
    );
  }
}
