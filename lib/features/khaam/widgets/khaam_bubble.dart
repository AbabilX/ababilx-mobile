import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-select/message_selection.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_payload.dart';
import '../data/jpack_status.dart';
import '../providers/jpack_providers.dart';
import '../screens/jpack_open_route.dart';
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
    final opened =
        ref.watch(jpackOpenedProvider(payload.id)).valueOrNull ?? false;
    final selecting = ref.watch(messageSelectionProvider).isActive;
    final failed = message.sendStatus == MessageSendStatus.failed;
    final state = jpackStatus(isOwn: isOwn, opened: opened);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = switch (state) {
      JPackStatus.sent => t('jpack_sent'),
      JPackStatus.opened => t('jpack_opened'),
      JPackStatus.unopened => t('jpack_tap_to_open'),
    };

    final card = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: state == JPackStatus.opened ? 0.62 : 1,
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: JPackCoverArt(cover: cover, width: 44, radius: 4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        payload.message.trim().isEmpty
                            ? 'JPack'
                            : payload.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: colors.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Icon(Icons.mail_rounded, size: 14, color: cover.flap),
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
                    color: state == JPackStatus.unopened
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
}
