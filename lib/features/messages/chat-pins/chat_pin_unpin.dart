import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-timeline/pinned_message_actions.dart';
import '../group-member-permissions/group_admin_api.dart';
import '../group-pins/group_pin_actions.dart';
import '../group-pins/group_pins_provider.dart';
import 'chat_pins_provider.dart';

/// Takes one row off the Pins page: the caller's own pin and, when they may,
/// the group's shared one — the row is one message, so Unpin clears both.
Future<void> unpinChatPin(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  ChatPinEntry entry, {
  required bool canPinGroup,
}) async {
  final id = entry.message.id;
  if (entry.everyone && canPinGroup) {
    await setGroupPinned(context, ref, conversationId, id, pinned: false);
  }
  if (entry.mine && context.mounted) {
    await setMessagePinned(context, ref, conversationId, id, pinned: false);
  }
}

/// "Unpin all": every row [unpinChatPin] could take, one request each (no
/// bulk route on either side). Stops at the first failure so the page shown
/// afterwards is the server's truth; answers whether all of them went.
Future<bool> unpinAllChatPins(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  ChatPinsView view,
) async {
  final shared = [
    for (final e in view.entries)
      if (e.everyone && view.canPinGroup) e.message.id,
  ];
  if (shared.isNotEmpty) {
    final client = ref.read(apiClientProvider);
    try {
      for (final id in shared) {
        await deleteGroupPin(client, conversationId, id);
      }
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
      ref.invalidate(groupPinsProvider(conversationId));
    }
  }
  final own = [
    for (final e in view.entries)
      if (e.mine) e.message.id,
  ];
  if (own.isEmpty || !context.mounted) return own.isEmpty;
  return unpinAllMessages(context, ref, conversationId, own);
}
