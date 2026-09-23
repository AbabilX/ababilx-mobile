import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/chat_repository.dart';
import '../providers/pinned_message_provider.dart';

Future<void> changePinnedMessage(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String? messageId,
) async {
  try {
    await ref
        .read(chatRepositoryProvider)
        .setPinnedMessage(conversationId, messageId);
    ref.invalidate(pinnedMessageProvider(conversationId));
  } catch (_) {
    if (context.mounted) {
      showAppToast(
        context,
        AppTranslations.translate(context, ref, 'chat_pin_failed'),
        isError: true,
      );
    }
  }
}
