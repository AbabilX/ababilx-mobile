import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../messages/chat_icon.dart';

/// What a DM shows in place of online / offline / in a call when the other
/// person has privacy mode on: one neutral word, so the absence of a status
/// reads as a choice they made and not as a fault.
class PrivacyStatusLabel extends ConsumerWidget {
  const PrivacyStatusLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatIcon(HugeIcons.strokeRoundedShield01, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          AppTranslations.translate(context, ref, 'chat_status_privacy'),
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
