import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../data/share_thread_queries.dart';
import '../providers/share_chat_pins.dart';
import '../providers/share_in_chats.dart';
import '../share_text.dart';

enum _RowAction { pin, unpin, remove }

/// Long press on a device thread in the chat list: pin it (the gesture a
/// conversation takes), or send it back to Local Share. Everything else
/// (block, forget) stays behind the thread's own menu.
Future<void> showShareChatRowSheet(
  BuildContext context,
  WidgetRef ref,
  ShareThread thread,
) async {
  final deviceId = thread.device.deviceId;
  final pinned =
      ref.read(shareChatPinsProvider).valueOrNull?.contains(deviceId) ?? false;
  final action = await showModalBottomSheet<_RowAction>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: ChatIcon(
              pinned
                  ? HugeIcons.strokeRoundedPinOff
                  : HugeIcons.strokeRoundedPin,
            ),
            title: Text(lsText(ref, pinned ? 'ls_unpin_chat' : 'ls_pin_chat')),
            onTap: () => Navigator.pop(
              sheet,
              pinned ? _RowAction.unpin : _RowAction.pin,
            ),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedBubbleChatCancel),
            title: Text(lsText(ref, 'ls_hide_from_chats')),
            subtitle: Text(lsText(ref, 'ls_hide_from_chats_sub')),
            onTap: () => Navigator.pop(sheet, _RowAction.remove),
          ),
        ],
      ),
    ),
  );
  switch (action) {
    case _RowAction.pin || _RowAction.unpin:
      final ok = await ref
          .read(shareChatPinsProvider.notifier)
          .setPinned(deviceId, action == _RowAction.pin);
      if (!ok && context.mounted) {
        showAppToast(context, lsText(ref, 'ls_pin_limit'), isError: true);
      }
    case _RowAction.remove:
      await ref.read(shareInChatsProvider.notifier).setShown(deviceId, false);
      await ref.read(shareChatPinsProvider.notifier).setPinned(deviceId, false);
    case null:
      break;
  }
}
