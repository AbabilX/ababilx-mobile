import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../providers/share_quick_button.dart';
import '../share_text.dart';

/// Long press on the round Local Share button in the home bar: the one thing
/// to do from there is take it off the bar. Local Share's own page turns it
/// back on.
Future<void> showQuickButtonSheet(BuildContext context, WidgetRef ref) async {
  final remove = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListTile(
        leading: const ChatIcon(HugeIcons.strokeRoundedDelete02),
        title: Text(lsText(ref, 'ls_quick_remove')),
        subtitle: Text(lsText(ref, 'ls_quick_remove_sub')),
        onTap: () => Navigator.pop(sheet, true),
      ),
    ),
  );
  if (remove != true) return;
  await ref.read(shareQuickButtonProvider.notifier).set(false);
}
