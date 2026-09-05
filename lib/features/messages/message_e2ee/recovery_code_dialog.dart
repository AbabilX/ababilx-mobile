import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_vault.dart';
import 'recovery_code_card.dart';

/// Replaces the account's message recovery code.
///
/// There is deliberately no "show my code" here, and there cannot be: the code
/// is never stored — not on the server, not on this phone — so the only thing
/// anyone can do is issue a new one. That re-wraps the same message key, so all
/// history stays readable and the previous code stops working immediately.
///
/// It needs a device that already holds the key, since the new wrapping is made
/// from it locally. That is the same property that makes the messages
/// end-to-end encrypted in the first place.
class RecoveryCodeDialog extends ConsumerStatefulWidget {
  const RecoveryCodeDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const RecoveryCodeDialog());

  @override
  ConsumerState<RecoveryCodeDialog> createState() => _State();
}

class _State extends ConsumerState<RecoveryCodeDialog> {
  String _code = '';
  bool _busy = false;
  String? _error;

  Future<void> _regenerate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await ref.read(messageVaultProvider).regenerateRecoveryCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is StateError
            ? error.message
            : 'Could not make a new code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Message recovery code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your messages are end-to-end encrypted. This code is what unlocks '
            'them on a new device — we do not have a copy and cannot show you '
            'the old one, only replace it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (_code.isNotEmpty) ...[
            RecoveryCodeCard(code: _code),
            const SizedBox(height: 8),
            Text(
              'Save this now. Your previous code no longer works.',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _regenerate,
                child: Text(_busy ? 'Making a new code…' : 'Generate a new code'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_code.isEmpty ? 'Cancel' : 'Done'),
        ),
      ],
    );
  }
}
