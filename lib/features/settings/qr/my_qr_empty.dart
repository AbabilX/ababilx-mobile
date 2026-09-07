import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// No handle, no code. The screen says what is missing and offers the one
/// action that fixes it, rather than drawing an empty frame.
class MyQrEmpty extends StatelessWidget {
  const MyQrEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 72,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              'Pick a username first',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your QR code carries your username, so people who scan it land '
              'on your chat. Nothing else is in the code.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/settings/username'),
              child: const Text('Choose a username'),
            ),
          ],
        ),
      ),
    );
  }
}
