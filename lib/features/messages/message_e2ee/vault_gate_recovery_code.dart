import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_vault.dart';
import '../../../core/localization/app_translations.dart';

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
    required this.onBack,
  });

  final Future<void> Function() onUnlocked;

  final VoidCallback onBack;

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
    if (_busy) return;
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
            ? 'recovery_invalid'
            : 'recovery_failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String t(String key) => AppTranslations.translate(context, ref, key);
    return PopScope(
      canPop: !_busy,
      child: Center(
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
                t('recovery_enter'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t('recovery_help'),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
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
                  t(_error!),
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
                  child: Text(
                    t(_busy ? 'recovery_working' : 'recovery_restore'),
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : widget.onBack,
                child: Text(t('recovery_back')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
