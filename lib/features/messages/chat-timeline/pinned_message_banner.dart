import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_message.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../providers/pinned_message_provider.dart';
import '../tiptap_plain_text.dart';
import 'pinned_message_actions.dart';
import 'timeline_jump.dart';

/// A personal pin stays reachable from the chat even after its row scrolls out.
class PinnedMessageBanner extends ConsumerWidget {
  const PinnedMessageBanner({
    super.key,
    required this.conversationId,
    required this.messages,
  });

  final String conversationId;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedId = ref
        .watch(pinnedMessageProvider(conversationId))
        .valueOrNull;
    if (pinnedId == null) return const SizedBox.shrink();
    final message = messages.where((item) => item.id == pinnedId).firstOrNull;
    if (message?.isDeleted ?? false) return const SizedBox.shrink();
    // A body this device never opened is the vault's stand-in, not a preview.
    final body =
        message == null ||
            message.contentPurged ||
            isVaultPlaceholderBody(message.body)
        ? ''
        : tiptapToPlainText(message.body).trim();
    final colors = Theme.of(context).colorScheme;
    String tr(String key) => AppTranslations.translate(context, ref, key);

    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final found = await TimelineJumpScope.maybeOf(
                    context,
                  )?.jumpTo(pinnedId);
                  if (found == false && context.mounted) {
                    showAppToast(
                      context,
                      tr('chat_pin_not_found'),
                      isError: true,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_rounded, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('chat_pinned_message')),
                            if (body.isNotEmpty)
                              Text(
                                body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
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
            IconButton(
              tooltip: tr('chat_unpin_message'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () =>
                  changePinnedMessage(context, ref, conversationId, null),
            ),
          ],
        ),
      ),
    );
  }
}
