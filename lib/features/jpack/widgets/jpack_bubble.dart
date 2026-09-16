import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-select/message_selection.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_money.dart';
import '../data/jpack_payload.dart';
import '../data/jpack_status.dart';
import '../providers/jpack_providers.dart';
import '../screens/jpack_open_screen.dart';
import 'ababil_pay_sheet.dart';
import 'jpack_cover_art.dart';

/// A JPack in the timeline. Fills the bubble edge to edge, like media; the
/// bubble's own footer (time, ticks) sits under it.
class JPackBubbleCard extends ConsumerWidget {
  const JPackBubbleCard({
    super.key,
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  static const width = 232.0;

  final ChatMessage message;
  final JPackPayload payload;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final cover = jpackCoverById(payload.coverId);
    final claimed =
        ref.watch(jpackClaimedProvider(payload.id)).valueOrNull ?? false;
    final selecting = ref.watch(messageSelectionProvider).isActive;
    final failed = message.sendStatus == MessageSendStatus.failed;
    // Read at build: a bubble on screen across the 48-hour mark updates on
    // its next rebuild, and the open screen checks again before it pays.
    final left = jpackTimeLeft(message);
    final state = jpackStatus(
      isOwn: isOwn,
      claimed: claimed,
      expired: left == Duration.zero,
    );
    final expired =
        state == JPackStatus.expired || state == JPackStatus.claimClosed;
    final dim = state == JPackStatus.opened;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = switch (state) {
      JPackStatus.sent => t('jpack_sent'),
      JPackStatus.opened => t('jpack_opened'),
      JPackStatus.expired => t('jpack_expired'),
      JPackStatus.claimClosed => t('jpack_claim_closed'),
      // The last 12 hours count down, so "tap to open" gains some urgency.
      JPackStatus.claimable when left != null && left.inHours < 12 =>
        left.inHours >= 1
            ? t('jpack_expires_in_hours').replaceAll('{n}', '${left.inHours}')
            : t(
                'jpack_expires_in_minutes',
              ).replaceAll('{n}', '${math.max(1, left.inMinutes)}'),
      JPackStatus.claimable => t('jpack_tap_to_open'),
    };

    final card = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: expired ? 0.5 : (dim ? 0.62 : 1),
            child: ColorFiltered(
              colorFilter: expired ? _desaturate : _identity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(cover.flap, Colors.white, 0.12)!,
                      cover.flap,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: JPackCoverArt(
                          cover: cover,
                          width: 44,
                          radius: 4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              payload.message.trim().isEmpty
                                  ? 'JPack'
                                  : payload.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cover.accent.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                formatTaka(payload.amount),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Color.lerp(
                                    cover.flap,
                                    Colors.black,
                                    0.35,
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: colors.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                const AbabilPayMark(size: 14),
                const SizedBox(width: 6),
                Text(
                  'JPack',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: switch (state) {
                      JPackStatus.claimable => cover.flap,
                      JPackStatus.expired => colors.error,
                      _ => colors.onSurfaceVariant,
                    },
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
        onTap: () => openJPack(
          context,
          message: message,
          payload: payload,
          isOwn: isOwn,
        ),
        child: card,
      ),
    );
  }

  static const _identity = ColorFilter.matrix(<double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  static const _desaturate = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}
