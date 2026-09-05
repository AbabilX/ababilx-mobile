import 'package:flutter/material.dart';

import '../../../core/network/friendly_error.dart';

/// Offline/failed state for the vault gate, with a retry rather than a spinner
/// that never resolves.
class VaultGateError extends StatelessWidget {
  const VaultGateError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = describeLoadError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(copy.icon, size: 40),
            const SizedBox(height: 16),
            Text(
              copy.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(copy.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
