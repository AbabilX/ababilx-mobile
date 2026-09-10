import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-list/index.dart';
import '../history-restore/recovery_progress_banner.dart';
import '../archive/archive_provider.dart';
import '../history-restore/history_restore_state.dart';
import '../message_e2ee/message_vault.dart';
import '../message_e2ee/message_vault_sheet.dart';
import '../providers/chat_provider.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _vaultUnlocked = false;
  bool _vaultSheetOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    // Local-only restore (secure-storage read + in-memory key check, no
    // server round-trip) — never blocks this screen on the network.
    unawaited(_restoreVaultOffline());
  }

  Future<void> _bootstrap() async {
    final chat = ref.read(chatProvider.notifier);
    await chat.ensureReady();
    if (mounted) await chat.startHistoryRestoreIfNeeded();
  }

  Future<void> _restoreVaultOffline() async {
    final unlocked = await ref
        .read(messageVaultProvider)
        .restoreTrustedIdentityOffline();
    if (!mounted) return;
    if (unlocked) {
      final chat = ref.read(chatProvider.notifier);
      // The fetch reopens previews only if it reaches the server; the rows
      // already on screen are reopened from this device either way.
      unawaited(chat.decryptSidebarPreviews());
      unawaited(chat.fetchSidebar(silent: true));
    }
    setState(() => _vaultUnlocked = unlocked);
    if (!unlocked) _openUnlockSheet();
  }

  Future<void> _openUnlockSheet() async {
    if (_vaultSheetOpen || ref.read(messageVaultProvider).isUnlocked) return;
    _vaultSheetOpen = true;
    await showMessageVaultRecoverySheet(
      context: context,
      onUnlocked: () {
        if (!mounted) return;
        unawaited(ref.read(chatProvider.notifier).decryptSidebarPreviews());
        setState(() => _vaultUnlocked = true);
      },
    );
    _vaultSheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    // The conversation list is the screen for every account — no team gate,
    // no network gate, no E2EE gate. Chat is not a workspace feature any more,
    // so a user with no workspace gets the same header, search and composer;
    // the list under them is simply empty until they connect with someone.
    // Sealed previews (DMs and groups) carry a safe "Encrypted message"
    // placeholder until the vault is unlocked, and the vault only gates an
    // individual chat's content, in ConversationScreen.
    return _MessagesBody(
      vaultUnlocked: _vaultUnlocked,
      onUnlockTap: _openUnlockSheet,
    );
  }
}

/// The chat list plus a small header banner — unlock while the vault is
/// locked, restoring after recovery, never both, never a full-screen block.
class _MessagesBody extends ConsumerWidget {
  const _MessagesBody({required this.vaultUnlocked, required this.onUnlockTap});

  final bool vaultUnlocked;
  final VoidCallback onUnlockTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyRestoreProvider);
    final archive = ref.watch(archiveProvider);
    final restoring =
        history.running ||
        history.failed ||
        archive.phase == ArchivePhase.restoring ||
        archive.error.isNotEmpty;
    return ChatList(
      banner: !vaultUnlocked
          ? _UnlockBanner(onTap: onUnlockTap)
          : restoring
          ? const RecoveryProgressBanner()
          : null,
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
