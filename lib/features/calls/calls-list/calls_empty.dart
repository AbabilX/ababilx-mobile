import 'package:flutter/material.dart';

/// Nothing to show yet — or the first page failed. Both land here, because an
/// empty history and an unreachable server look identical to the user until
/// the message says otherwise.
class CallsEmpty extends StatelessWidget {
  const CallsEmpty({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final failed = error != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off_rounded : Icons.call_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              failed ? 'Call history unavailable' : 'No calls yet',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              failed
                  ? 'Check your connection and pull to refresh.'
                  : 'Calls you make and receive show up here.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
