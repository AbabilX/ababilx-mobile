import 'package:flutter/material.dart';

/// The two lines of text on the Linked devices screen that are not a device:
/// the empty/failed state, and the encryption footer.
///
/// They live here so the screen file stays the screen — the list, the actions
/// and nothing else.

class DevicesNote extends StatelessWidget {
  const DevicesNote(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Text(
        text,
        style: TextStyle(color: color ?? colors.onSurfaceVariant),
      ),
    );
  }
}

class DevicesEncryptionNote extends StatelessWidget {
  const DevicesEncryptionNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
