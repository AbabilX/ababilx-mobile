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
  bool _checkingVault = true;
  bool _vaultUnlocked = false;

  @override
  void initState() {
    super.initState();
    _restoreVault();
  }

  Future<void> _restoreVault() async {
    final unlocked = await ref
        .read(messageVaultProvider)
        .restoreTrustedIdentity();
    if (!mounted) return;
    if (unlocked) {
      await ref.read(chatProvider.notifier).fetchSidebar(silent: true);
    }
    if (mounted) {
      setState(() {
        _checkingVault = false;
        _vaultUnlocked = unlocked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamGateProvider);

    return teamAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (_, _) => const Scaffold(
        body: ChatEmptyState(
          title: 'Could not load team',
          subtitle: 'Pull to refresh or try again later.',
          icon: Icons.error_outline,
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
        if (_checkingVault) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }
        return Stack(
          children: [
            const ChatList(),
            if (!_vaultUnlocked)
              Positioned.fill(
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: MessageVaultGate(
                    onUnlocked: () {
                      setState(() => _vaultUnlocked = true);
                      ref
                          .read(chatProvider.notifier)
                          .fetchSidebar(silent: true);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
