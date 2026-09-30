import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/swipe_tab_active.dart';
import '../../../shared/widgets/portrait_lock_scope.dart';
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
  bool _vaultChecked = false;

  /// Once, on the first moment this tab is on screen. The Chats/Talks pager
  /// builds Talks early, while Chats already asks for the same unlock.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vaultChecked || !SwipeTabActive.of(context)) return;
    _vaultChecked = true;
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
  Widget build(BuildContext context) =>
      const PortraitLockScope(child: CallsList());
}
