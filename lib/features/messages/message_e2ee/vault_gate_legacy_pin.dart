import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_vault.dart';

/// The last message PIN prompt this account will ever see.
///
/// Accounts made before message keys became device-local still have a copy on
/// the server wrapped in six digits. Entering the PIN once moves the key onto
/// this phone and deletes that server copy; after this the screen is gone for
/// good, and new accounts never reach it.
class VaultGateLegacyPin extends ConsumerStatefulWidget {
  const VaultGateLegacyPin({super.key, required this.onUnlocked});
  final Future<void> Function() onUnlocked;

  @override
  ConsumerState<VaultGateLegacyPin> createState() => _VaultGateLegacyPinState();
}

class _VaultGateLegacyPinState extends ConsumerState<VaultGateLegacyPin> {
  final _pin = TextEditingController();
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(messageVaultProvider).unlock(_pin.text);
      await widget.onUnlocked();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 16),
              const Text(
                'Enter your message PIN one last time',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your key moves onto this device and the copy on our servers '
                'is deleted. You will not be asked for a PIN again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: '6-digit message PIN',
                  counterText: '',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _working ? null : _submit,
                  icon: _working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock and finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
