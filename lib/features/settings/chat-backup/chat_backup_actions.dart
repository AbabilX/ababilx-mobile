import 'package:flutter/material.dart';

/// The two buttons, kept apart from the screen so neither file grows past the
/// project's size rule.
class ChatBackupActions extends StatelessWidget {
  const ChatBackupActions({
    super.key,
    required this.busy,
    required this.canRestore,
    required this.onBackUp,
    required this.onRestore,
  });

  final bool busy;
  final bool canRestore;
  final VoidCallback onBackUp;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onBackUp,
          icon: const Icon(Icons.backup_outlined, size: 18),
          label: const Text('Back up now'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          // Nothing to restore is a state, not an error: a first backup has to
          // happen before there is anything to bring back.
          onPressed: busy || !canRestore ? null : onRestore,
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: Text(canRestore ? 'Restore' : 'Nothing to restore yet'),
        ),
      ],
    ),
  );
}
