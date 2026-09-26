import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../providers/pinned_message_provider.dart';
import 'details_action_button.dart';

/// "Pins" beside Search on the details screen, drawn only while this chat has
/// a pin — a button that opens an empty list is a dead control. Choosing a
/// pin closes this screen with its id, and the chat under it walks to it.
/// Carries its own leading gap so the row stays even when it is absent.
class PinnedMessagesAction extends ConsumerWidget {
  const PinnedMessagesAction({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(pinnedMessagesProvider(conversationId)).valueOrNull?.length ??
        0;
    if (count == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 16),
        DetailsActionButton(
          icon: const ChatIcon(HugeIcons.strokeRoundedPin),
          label: AppTranslations.translate(context, ref, 'chat_pins_action'),
          onTap: () async {
            final messageId = await context.push<String>(
              '/messages/$conversationId/pins',
            );
            if (messageId != null && context.mounted) context.pop(messageId);
          },
        ),
      ],
    );
  }
}
