import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../providers/auth_provider.dart';
import '../widgets/account_switch_prompt.dart';
import '../widgets/google_sign_in_action.dart';
import 'start_new_chat_sheet.dart';

/// The first and loudest way in: a new account with nothing asked — no
/// email, no Google, no phone, no name.
class StartNewChatAction extends StatelessWidget {
  const StartNewChatAction({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;

  /// This button's own request is running (spinner).
  final bool busy;

  /// Null while any sign-in is running.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.55),
          disabledForegroundColor: colors.onPrimary,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.onPrimary,
                ),
              )
            else
              ChatIcon(
                HugeIcons.strokeRoundedBubbleChatAdd,
                size: 22,
                color: colors.onPrimary,
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

/// Google first, if they want an account that survives the phone; Skip
/// makes the key-only account as before. Dismissed: nothing happens.
Future<void> runStartNewChat(BuildContext context, WidgetRef ref) async {
  final choice = await showStartNewChatSheet(context);
  if (choice == null || !context.mounted) return;
  if (choice == StartNewChatChoice.google) {
    return runGoogleSignIn(context, ref);
  }
  final outcome = await ref.read(authProvider.notifier).startNewChat();
  if (!context.mounted) return;
  await settleAccountSwitch(context, ref, outcome);
}
