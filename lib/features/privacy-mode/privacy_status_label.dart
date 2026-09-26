import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../messages/chat_icon.dart';

/// What a DM shows in place of online / offline / in a call when the other
/// person has privacy mode on: one neutral word, so the absence of a status
/// reads as a choice they made and not as a fault.
///
/// A DM with private chat on (server 0160) hides the same things in BOTH
/// directions and says so instead: "Private chat", with its own glyph.
class PrivacyStatusLabel extends ConsumerWidget {
  const PrivacyStatusLabel({super.key, this.privateChat = false});

  final bool privateChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatIcon(
          privateChat
              ? HugeIcons.strokeRoundedIncognito
              : HugeIcons.strokeRoundedShield01,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          AppTranslations.translate(
            context,
            ref,
            privateChat ? 'chat_status_private_chat' : 'chat_status_privacy',
          ),
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
