import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-timeline/pinned_message_actions.dart';
import '../group-member-permissions/group_admin_api.dart';
import 'group_pins_provider.dart';

enum _PinChoice { everyone, me }

/// Pin in a group whose viewer may pin for everyone: Telegram's pin is the
/// group's, ours was only ever private, so the menu's one row asks which.
/// Without the permission the row keeps its old meaning (for me) and this is
/// never reached.
Future<void> chooseGroupPin(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required String messageId,
  required bool pinnedForMe,
  required bool pinnedForEveryone,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final choice = await showModalBottomSheet<_PinChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedMegaphone01),
            title: Text(
              tr(pinnedForEveryone ? 'group_pin_unpin_all' : 'group_pin_all'),
            ),
            subtitle: pinnedForEveryone ? null : Text(tr('group_pin_all_hint')),
            onTap: () => Navigator.pop(sheet, _PinChoice.everyone),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedPin),
            title: Text(
              tr(pinnedForMe ? 'group_pin_unpin_me' : 'group_pin_me'),
            ),
            onTap: () => Navigator.pop(sheet, _PinChoice.me),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == _PinChoice.me) {
    await setMessagePinned(
      context,
      ref,
      conversationId,
      messageId,
      pinned: !pinnedForMe,
    );
    return;
  }
  await setGroupPinned(
    context,
    ref,
    conversationId,
    messageId,
    pinned: !pinnedForEveryone,
  );
}

/// Pins or unpins one message for every member.
Future<void> setGroupPinned(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String messageId, {
  required bool pinned,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final client = ref.read(apiClientProvider);
  try {
    pinned
        ? await putGroupPin(client, conversationId, messageId)
        : await deleteGroupPin(client, conversationId, messageId);
    ref.invalidate(groupPinsProvider(conversationId));
  } catch (error) {
    if (!context.mounted) return;
    final key = switch (serverErrorCode(error)) {
      'chat_group_pin_limit' => 'group_pin_limit',
      'pin_restricted' => 'group_perm_err_pin',
      _ => 'chat_pin_failed',
    };
    showAppToast(context, tr(key), isError: true);
  }
}
