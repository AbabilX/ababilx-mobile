import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../engine/store/share_records.dart';
import '../local_share_actions.dart';
import '../local_share_engine.dart';
import '../providers/share_in_chats.dart';
import '../share_text.dart';

/// Move the thread into the chat list, block, or forget the device (thread
/// deleted, it has to ask again).
/// Returns true when the thread no longer exists and the screen should close.
Future<bool> showShareThreadMenu(
  BuildContext context,
  WidgetRef ref,
  LocalShareEngine engine,
  ShareDeviceRecord device,
) async {
  final inChats =
      ref.read(shareInChatsProvider).valueOrNull?.contains(device.deviceId) ??
      false;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final error = Theme.of(sheet).colorScheme.error;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!device.blocked)
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedBubbleChat),
                title: Text(
                  lsText(
                    ref,
                    inChats ? 'ls_hide_from_chats' : 'ls_show_in_chats',
                  ),
                ),
                subtitle: Text(
                  lsText(
                    ref,
                    inChats ? 'ls_hide_from_chats_sub' : 'ls_show_in_chats_sub',
                  ),
                ),
                onTap: () => Navigator.pop(sheet, 'chats'),
              ),
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedUserBlock01),
              title: Text(
                lsText(ref, device.blocked ? 'ls_unblock' : 'ls_block'),
              ),
              subtitle: device.blocked
                  ? null
                  : Text(lsText(ref, 'ls_block_sub')),
              onTap: () => Navigator.pop(sheet, 'block'),
            ),
            ListTile(
              leading: ChatIcon(HugeIcons.strokeRoundedDelete02, color: error),
              title: Text(
                lsText(ref, 'ls_forget'),
                style: TextStyle(color: error),
              ),
              subtitle: Text(lsText(ref, 'ls_forget_sub')),
              onTap: () => Navigator.pop(sheet, 'forget'),
            ),
          ],
        ),
      );
    },
  );
  final chats = ref.read(shareInChatsProvider.notifier);
  if (choice == 'chats') {
    await chats.setShown(device.deviceId, !inChats);
    return false;
  }
  if (choice == 'block') {
    await engine.setBlocked(device.deviceId, !device.blocked);
    return false;
  }
  if (choice == 'forget') {
    await engine.forgetDevice(device.deviceId);
    await chats.setShown(device.deviceId, false);
    return true;
  }
  return false;
}
