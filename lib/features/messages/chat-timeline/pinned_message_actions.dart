import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/chat_repository.dart';
import '../providers/pinned_message_provider.dart';
import 'timeline_jump.dart';

/// Pins or unpins one message for the caller alone. A pin has no bar in the
/// chat any more, so pinning says where the list lives. Answers whether it
/// went.
Future<bool> setMessagePinned(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String messageId, {
  required bool pinned,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  try {
    await ref
        .read(chatRepositoryProvider)
        .setMessagePinned(conversationId, messageId, pinned: pinned);
    ref.invalidate(pinnedMessagesProvider(conversationId));
    if (pinned && context.mounted) {
      showAppToast(context, tr('chat_pinned_toast'));
    }
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    final limit =
        error is DioException &&
        error.response?.statusCode == 409 &&
        error.toString().contains('chat_message_pin_limit');
    showAppToast(
      context,
      tr(limit ? 'chat_pin_limit' : 'chat_pin_failed'),
      isError: true,
    );
    return false;
  }
}

/// Removes every pin in [messageIds], one request each (the server has no
/// bulk route). Stops at the first failure so the list shown afterwards is the
/// server's truth; answers whether all of them went.
Future<bool> unpinAllMessages(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  List<String> messageIds,
) async {
  final repo = ref.read(chatRepositoryProvider);
  try {
    for (final id in messageIds) {
      await repo.setMessagePinned(conversationId, id, pinned: false);
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppToast(
        context,
        AppTranslations.translate(context, ref, 'chat_pin_failed'),
        isError: true,
      );
    }
    return false;
  } finally {
    ref.invalidate(pinnedMessagesProvider(conversationId));
  }
}

/// Walks the open timeline to a pinned message. Reports it when the message
/// cannot be reached — outside the history this chat still keeps.
Future<void> jumpToPinnedMessage(
  BuildContext context,
  WidgetRef ref,
  String messageId,
) async {
  final found = await TimelineJumpScope.maybeOf(context)?.jumpTo(messageId);
  if (found == false && context.mounted) {
    showAppToast(
      context,
      AppTranslations.translate(context, ref, 'chat_pin_not_found'),
      isError: true,
    );
  }
}
