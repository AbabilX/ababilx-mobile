import 'package:flutter/material.dart';

import 'recovery_code_card.dart';

/// Shown once, when a recovery code is created.
///
/// It stands in front of the chat deliberately. The code cannot be shown again
/// — neither AbabilX nor this phone keeps a copy — so a banner that could be
/// swiped past would turn into a lost history on the next device. The checkbox
/// is friction on purpose.
class VaultGateRecoverySetup extends StatefulWidget {
  const VaultGateRecoverySetup({
    super.key,
    required this.code,
    required this.onSaved,
  });
  final String code;
  final Future<void> Function() onSaved;

  @override
  State<VaultGateRecoverySetup> createState() => _VaultGateRecoverySetupState();
}

class _VaultGateRecoverySetupState extends State<VaultGateRecoverySetup> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Save your recovery code',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your messages are end-to-end encrypted, so we cannot read them '
              'and cannot restore them for you. This code is how you read them '
              'on a new device.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            RecoveryCodeCard(code: widget.code),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _saved,
              onChanged: (value) => setState(() => _saved = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I have saved this code somewhere safe.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saved ? () => widget.onSaved() : null,
                child: const Text('Continue to messages'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Lose it and your existing messages stay encrypted forever. You '
              'can replace it any time from Settings.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
