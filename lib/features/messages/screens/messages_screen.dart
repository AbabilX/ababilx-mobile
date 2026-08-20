import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-empty-state/index.dart';
import '../chat-list/index.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/message_vault_gate.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';

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
    final teamAsync = ref.watch(teamGateProvider);
    final chatState = ref.watch(chatProvider);
    final hasCachedChats =
        chatState.dms.isNotEmpty || chatState.channels.isNotEmpty;

    // WhatsApp-style: the conversation list is never blocked by anything —
    // not the network, not the E2EE vault. DM previews already show a safe
    // "Encrypted message" placeholder until unlocked; the vault only gates
    // an individual DM's actual content, in ConversationScreen.
    if (hasCachedChats) {
      return _MessagesBody(
        vaultUnlocked: _vaultUnlocked,
        onUnlockTap: _openUnlockSheet,
      );
    }

    return teamAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (_, _) => const Scaffold(
        body: ChatEmptyState(
          title: 'Waiting for connection',
          subtitle: 'Swipe down to refresh or check your internet.',
          icon: Icons.wifi_off_rounded,
        ),
      ),
      data: (detail) {
        if (detail == null || !detail.hasTeam) {
          return const Scaffold(
            body: ChatEmptyState(
              title: 'No team yet',
              subtitle:
                  'Join or create a team on the web to use workspace messages.',
              icon: Icons.groups_outlined,
            ),
          );
        }
        return _MessagesBody(
          vaultUnlocked: _vaultUnlocked,
          onUnlockTap: _openUnlockSheet,
        );
      },
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
    return Stack(
      children: [
        const ChatList(),
        if (!vaultUnlocked)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _UnlockBanner(onTap: onUnlockTap),
          ),
      ],
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
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
