import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'account_switch_prompt.dart';

class LoginGoogleAction extends StatelessWidget {
  const LoginGoogleAction({
    super.key,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    this.error,
  });

  final bool isLoading;
  final String label;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: 280.ms,
          child: isLoading
              ? const SizedBox(key: ValueKey('login-hidden'))
              : SizedBox(
                  key: const ValueKey('login-button'),
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.surfaceContainerLowest,
                      foregroundColor: colors.onSurface,
                      elevation: 0,
                      side: BorderSide(
                        color: colors.primary.withValues(alpha: 0.18),
                        width: 1.2,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ).animate().fadeIn(delay: 350.ms),
        if (error != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.error.withValues(alpha: 0.2)),
            ),
            child: Text(
              error!,
              style: TextStyle(color: colors.error),
              textAlign: TextAlign.center,
            ),
          ).animate().shake(delay: 100.ms),
        ],
      ],
    );
  }
}

Future<void> runGoogleSignIn(BuildContext context, WidgetRef ref) async {
  final outcome = await ref.read(authProvider.notifier).signInWithGoogle();
  if (!context.mounted) return;
  await settleAccountSwitch(context, ref, outcome);
}
