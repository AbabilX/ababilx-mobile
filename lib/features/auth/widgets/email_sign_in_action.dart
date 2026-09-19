import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The quieter second way in, under "Continue with Google": same pill, no
/// fill, so Google stays the obvious choice for most people.
class LoginEmailAction extends StatelessWidget {
  const LoginEmailAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.mail_outline_rounded),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: colors.surfaceContainerLowest.withValues(alpha: 0.7),
          side: BorderSide(color: colors.outlineVariant, width: 1.2),
          shape: const StadiumBorder(),
        ),
      ),
    ).animate().fadeIn(delay: 420.ms);
  }
}
