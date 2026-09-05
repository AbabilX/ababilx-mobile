import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import 'message_vault.dart';

/// "Start fresh": an emailed code, then a brand-new message identity for
/// somebody locked out of every device that held the old one, with no recovery
/// code either.
///
/// It states the loss before it asks for anything. Every existing message stays
/// sealed to a key nobody has, including us — that is not a bug to be softened
/// in the copy, it is what end-to-end encryption costs when the last copy of a
/// key is gone.
///
/// Returns the new recovery code on success, so the caller can show it.
class VaultGateResetDialog extends ConsumerStatefulWidget {
  const VaultGateResetDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const VaultGateResetDialog(),
  );

  @override
  ConsumerState<VaultGateResetDialog> createState() => _State();
}

class _State extends ConsumerState<VaultGateResetDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _saving = false;
  String _sentTo = '';
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .requestE2eeResetCode();
      if (!mounted) return;
      setState(() {
        _sentTo = (sent['email'] as String?) ?? '';
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not send the code';
        _sending = false;
      });
    }
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 9) {
      setState(() => _error = 'Enter the 9-character code from your email.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final recovery = await ref
          .read(messageVaultProvider)
          .startFreshIdentity(code);
      if (mounted) Navigator.of(context).pop(recovery);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'That code is wrong or expired';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Start fresh'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This gives you a new encryption identity so you can send messages '
            'again. Everything already in your chats stays unreadable — nobody, '
            'including AbabilX, holds that key.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (_sentTo.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _sending ? null : _requestCode,
                child: Text(_sending ? 'Sending…' : 'Email me a code'),
              ),
            )
          else ...[
            Text('Code sent to $_sentTo', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              maxLength: 9,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '9-character code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_sentTo.isNotEmpty)
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Working…' : 'Start fresh'),
          ),
      ],
    );
  }
}
