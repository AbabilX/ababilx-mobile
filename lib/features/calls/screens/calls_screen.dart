import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/message_e2ee/message_vault_sheet.dart';
import '../calls-list/index.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  bool _vaultSheetOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreMessages());
  }

  Future<void> _restoreMessages() async {
    final vault = ref.read(messageVaultProvider);
    if (!vault.isUnlocked) {
      await vault.restoreTrustedIdentityOffline();
    }
    if (!mounted || vault.isUnlocked || _vaultSheetOpen) return;
    _vaultSheetOpen = true;
    await showMessageVaultRecoverySheet(context: context, onUnlocked: () {});
    _vaultSheetOpen = false;
  }

  @override
  Widget build(BuildContext context) => const CallsList();
}
