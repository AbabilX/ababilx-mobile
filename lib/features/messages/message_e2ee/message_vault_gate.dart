import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../providers/chat_provider.dart';
import 'message_vault.dart';
import 'vault_gate_error.dart';
import 'vault_gate_legacy_pin.dart';
import 'vault_gate_link.dart';

/// Stands in front of the chat until this device holds the account's message
/// key.
///
/// On a first launch it mints one and gets out of the way without a single
/// prompt: the private key is made here and only the public half is published,
/// so there is nothing for a PIN to protect. It only asks for something when
/// the account has an identity this device does not — then the key has to come
/// from a device that has it.
class MessageVaultGate extends ConsumerStatefulWidget {
  const MessageVaultGate({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<MessageVaultGate> createState() => _MessageVaultGateState();
}

class _MessageVaultGateState extends ConsumerState<MessageVaultGate> {
  // Tracked by hand rather than as a bare Future in a FutureBuilder: a builder
  // only ever checks snapshot.hasData, so a thrown or timed-out check would
  // spin forever instead of offering a retry.
  bool _checking = true;
  Object? _error;
  VaultIdentityState _state = VaultIdentityState.link;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final state = await ref
          .read(messageVaultProvider)
          .ensureIdentity()
          .timeout(firstLoadNetworkTimeout);
      if (!mounted) return;
      setState(() {
        _state = state;
        _checking = false;
      });
      if (state == VaultIdentityState.ready) await _finish();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _checking = false;
      });
    }
  }

  /// Shared by every route into a working vault. Any DM bubble hydrated from a
  /// previous session is still showing the locked placeholder, so it is
  /// resolved here rather than in each caller.
  Future<void> _finish() async {
    await ref.read(chatProvider.notifier).fetchSidebar(silent: true);
    await ref.read(chatProvider.notifier).redecryptFailedMessages();
    if (mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return VaultGateError(error: _error!, onRetry: _load);
    }
    if (_state == VaultIdentityState.ready) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_state == VaultIdentityState.legacy) {
      return VaultGateLegacyPin(onUnlocked: _finish);
    }
    return VaultGateLink(onLinked: _finish);
  }
}
