import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_vault.dart';
import 'vault_gate_reset_dialog.dart';

/// Unlocks this phone with the recovery code its owner saved.
///
/// The code is turned into a key on this device and never sent anywhere. What
/// the server stored is ciphertext it cannot open, so a correct code here
/// restores the same identity — and with it every message the account has ever
/// received.
class VaultGateRecoveryCode extends ConsumerStatefulWidget {
  const VaultGateRecoveryCode({
    super.key,
    required this.onUnlocked,
    required this.onIdentityReplaced,
  });

  final Future<void> Function() onUnlocked;

  /// Called with a brand-new recovery code after "start fresh", so the caller
  /// can show it. The user has just proved they keep nothing; handing them the
  /// replacement without showing it would repeat the same dead end.
  final void Function(String code) onIdentityReplaced;

  @override
  ConsumerState<VaultGateRecoveryCode> createState() => _State();
}

class _State extends ConsumerState<VaultGateRecoveryCode> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(messageVaultProvider)
          .unlockWithRecoveryCode(_controller.text);
      await widget.onUnlocked();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ArgumentError || error is StateError
            ? '${(error as dynamic).message}'
            : 'Could not unlock messages';
      });
    }
  }

  Future<void> _startFresh() async {
    final code = await VaultGateResetDialog.show(context);
    if (code != null) widget.onIdentityReplaced(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.vpn_key_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your recovery code',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The code you saved when you set up messages. Spacing and case do '
              'not matter.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              maxLines: 3,
              minLines: 3,
              style: const TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
              decoration: const InputDecoration(
                hintText: 'A1B2-C3D4-…',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Unlocking…' : 'Unlock messages'),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Lost the code and have no other device?',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _startFresh,
                child: const Text('Start fresh on this device'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Messaging works again after an emailed code. Messages you '
              'already have stay unreadable — nobody, including us, holds that '
              'key.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
