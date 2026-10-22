import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import 'continue_with_account_sheet.dart';
import 'google_sign_in_action.dart';

/// Second choice on the login screen: opens a sheet with Google and
/// email + password for people who already have an account.
class ContinueWithAccountAction extends StatelessWidget {
  const ContinueWithAccountAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;

  /// Null while any sign-in is running.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surfaceContainerLowest,
          foregroundColor: colors.onSurface,
          side: BorderSide(
            color: colors.primary.withValues(alpha: 0.18),
            width: 1.2,
          ),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedUserCircle,
              size: 22,
              color: colors.onSurface,
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
    ).animate().fadeIn(delay: 360.ms);
  }
}

Future<void> runContinueWithAccount(BuildContext context, WidgetRef ref) async {
  final choice = await showContinueWithAccountSheet(context);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case ContinueWithAccountChoice.google:
      await runGoogleSignIn(context, ref);
    case ContinueWithAccountChoice.email:
      context.push('/login/email');
  }
}
