import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../messages/chat_icon.dart';
import 'privacy_mode_provider.dart';

/// A small "Private" pill beside the chat list title while this account's own
/// privacy mode is on — the one switch that changes what everyone else sees
/// should never be on without the owner noticing. Tapping it opens the
/// setting. Draws nothing while privacy mode is off.
class PrivacyHeaderBadge extends ConsumerWidget {
  const PrivacyHeaderBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(privacyModeProvider)) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: colors.primaryContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.push('/settings/privacy-mode'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedShield01,
                  size: 14,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  AppTranslations.translate(context, ref, 'privacy_mode_badge'),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
