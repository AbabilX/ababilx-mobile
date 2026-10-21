import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Third and quietest: a text button for accounts that use email and
/// password. Same account, same id as before — only the way in moved down.
class LoginEmailAction extends StatelessWidget {
  const LoginEmailAction({
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
      height: 52,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.mail_outline_rounded),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: colors.surfaceContainerLowest.withValues(
            alpha: 0.55,
          ),
          shape: const StadiumBorder(),
        ),
      ),
    ).animate().fadeIn(delay: 420.ms);
  }
}
