import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';

Future<String?> showComposeSheet(
  BuildContext context, {
  required bool independent,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedBubbleChat),
              title: Text(
                AppTranslations.translate(context, ref, 'chat_new_message'),
              ),
              onTap: () => Navigator.pop(ctx, 'dm'),
            ),
            if (independent)
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedUserGroup),
                title: Text(
                  AppTranslations.translate(
                    context,
                    ref,
                    'chat_new_personal_group',
                  ),
                ),
                onTap: () => Navigator.pop(ctx, 'personal_group'),
              ),
            ListTile(
              leading: const Icon(Icons.tag_rounded),
              title: Text(
                AppTranslations.translate(
                  context,
                  ref,
                  independent ? 'chat_new_workspace_channel' : 'chat_new_group',
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'channel'),
            ),
          ],
        ),
      ),
    ),
  );
}
