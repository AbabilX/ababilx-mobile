import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import 'message_vault.dart';

class MessageVaultGate extends ConsumerStatefulWidget {
  const MessageVaultGate({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<MessageVaultGate> createState() => _MessageVaultGateState();
}

class _MessageVaultGateState extends ConsumerState<MessageVaultGate> {
  final _pin = TextEditingController();
  late final Future<bool> _hasVault;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hasVault = ref.read(messageVaultProvider).hasVault();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit(bool exists) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final vault = ref.read(messageVaultProvider);
      if (exists) {
        await vault.unlock(_pin.text);
      } else {
        await vault.setup(_pin.text);
      }
      await ref.read(chatProvider.notifier).fetchSidebar(silent: true);
      widget.onUnlocked();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _hasVault,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final exists = snapshot.data!;
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
                Text(
                  exists
                      ? 'Unlock private messages'
                      : 'Set up private messages',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  exists
                      ? 'Enter your 6-digit message PIN to read and send encrypted DMs on this device.'
                      : 'Create a 6-digit message PIN. You will need it on new devices to read and send encrypted DMs.',
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
                  onSubmitted: (_) => _submit(exists),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _working ? null : () => _submit(exists),
                    icon: _working
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(
                      exists ? 'Unlock messages' : 'Create message PIN',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
