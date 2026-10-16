import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../messages/chat_icon.dart';
import '../profile/delivery/delivery_only.dart';

/// The confirmation before private chat moves (server 0160). Switching it on
/// says exactly what both people get — it binds the other person too, so they
/// are told the same things in the timeline line. Answers true only when the
/// main button was pressed.
Future<bool> confirmPrivateChat(
  BuildContext context,
  WidgetRef ref, {
  required bool turnOn,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final deliveryOnly = ref.read(deliveryOnlyProvider);
  final go = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final colors = Theme.of(sheet).colorScheme;
      final text = Theme.of(sheet).textTheme;
      Widget point(List<List<dynamic>> icon, String key) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatIcon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(tr(key), style: text.bodyMedium)),
          ],
        ),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  turnOn
                      ? 'private_chat_sheet_title'
                      : 'private_chat_off_title',
                ),
                style: text.titleLarge,
              ),
              const SizedBox(height: 16),
              if (turnOn) ...[
                point(
                  HugeIcons.strokeRoundedCloudServer,
                  deliveryKey(
                    'private_chat_point_server',
                    deliveryOnly: deliveryOnly,
                  ),
                ),
                point(
                  HugeIcons.strokeRoundedViewOff,
                  'private_chat_point_status',
                ),
                point(
                  HugeIcons.strokeRoundedScreenLockRotation,
                  'private_chat_point_screens',
                ),
                point(
                  HugeIcons.strokeRoundedCallBlocked,
                  'private_chat_point_calls',
                ),
                point(
                  HugeIcons.strokeRoundedImageNotFound01,
                  'private_chat_point_media',
                ),
                point(
                  HugeIcons.strokeRoundedSmartPhone01,
                  'private_chat_point_phone',
                ),
              ] else
                Text(
                  tr(
                    deliveryKey(
                      'private_chat_off_body',
                      deliveryOnly: deliveryOnly,
                    ),
                  ),
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(
                  tr(turnOn ? 'private_chat_turn_on' : 'private_chat_turn_off'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(tr('cancel')),
              ),
            ],
          ),
        ),
      );
    },
  );
  return go == true;
}
