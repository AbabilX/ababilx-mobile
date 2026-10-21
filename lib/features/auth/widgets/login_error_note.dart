import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Why the last sign-in failed, under the buttons whichever one it was.
class LoginErrorNote extends StatelessWidget {
  const LoginErrorNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.error),
        textAlign: TextAlign.center,
      ),
    ).animate().shake(delay: 100.ms);
  }
}
