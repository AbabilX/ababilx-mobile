import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-list/index.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/message_vault_gate.dart';
import '../providers/chat_provider.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _vaultUnlocked = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(chatProvider.notifier).ensureReady());
    // Local-only restore (secure-storage read + in-memory key check, no
    // server round-trip) — never blocks this screen on the network.
    unawaited(_restoreVaultOffline());
  }

  Future<void> _restoreVaultOffline() async {
    final unlocked = await ref
        .read(messageVaultProvider)
        .restoreTrustedIdentityOffline();
    if (!mounted) return;
    if (unlocked) {
      unawaited(ref.read(chatProvider.notifier).fetchSidebar(silent: true));
    }
    setState(() => _vaultUnlocked = unlocked);
  }

  void _openUnlockSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.62,
          child: MessageVaultGate(
            onUnlocked: () {
              if (mounted) setState(() => _vaultUnlocked = true);
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The conversation list is the screen for every account — no team gate,
    // no network gate, no E2EE gate. Chat is not a workspace feature any more,
    // so a user with no workspace gets the same header, search and composer;
    // the list under them is simply empty until they connect with someone.
    // DM previews already carry a safe "Encrypted message" placeholder until
    // the vault is unlocked, and the vault only gates an individual DM's
    // content, in ConversationScreen.
    return _MessagesBody(
      vaultUnlocked: _vaultUnlocked,
      onUnlockTap: _openUnlockSheet,
    );
  }
}

/// The chat list plus a small, dismissible-by-tap unlock banner — never a
/// full-screen block. A user with no DMs, or channels only, never even sees
/// this banner's target matter.
class _MessagesBody extends StatelessWidget {
  const _MessagesBody({required this.vaultUnlocked, required this.onUnlockTap});

  final bool vaultUnlocked;
  final VoidCallback onUnlockTap;

  @override
  Widget build(BuildContext context) {
    return ChatList(
      banner: vaultUnlocked ? null : _UnlockBanner(onTap: onUnlockTap),
    );
  }
}

class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unlock to read encrypted messages',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
