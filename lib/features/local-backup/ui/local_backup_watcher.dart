import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/local_backup_settings.dart';
import '../local_backup_provider.dart';
import 'local_backup_restore_flow.dart';

/// Invisible host in the home shell for the two things local backup does on
/// its own: the scheduled run, and the one-time "Restore from a backup?".
///
/// Scheduled means "when the app opens, at most once in 12 hours" — there is
/// no background job yet, on purpose: a backup reads the unlocked message key,
/// which lives in this process, and a WorkManager isolate would have to
/// rebuild the whole vault to do it. The run waits 20 s after launch or resume
/// so it never competes with the chat list loading.
class LocalBackupWatcher extends ConsumerStatefulWidget {
  const LocalBackupWatcher({super.key});

  @override
  ConsumerState<LocalBackupWatcher> createState() => _LocalBackupWatcherState();
}

class _LocalBackupWatcherState extends ConsumerState<LocalBackupWatcher>
    with WidgetsBindingObserver {
  static const _settle = Duration(seconds: 20);
  static const _retry = Duration(seconds: 5);
  Timer? _timer;
  bool _checking = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attempts = 0;
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final userId = ref.read(chatProvider).currentUserId;
      // Bootstrap unlocks the vault a moment after the shell appears; keep
      // looking for a short while rather than miss the offer until a resume.
      if (userId.isEmpty || !ref.read(messageVaultProvider).isUnlocked) {
        if (_attempts++ < 12) {
          _timer?.cancel();
          _timer = Timer(_retry, _check);
        }
        return;
      }
      if (await const LocalBackupSettingsStore().takeRestoreOffer(userId) &&
          mounted) {
        await _offerRestore();
      }
      _timer?.cancel();
      _timer = Timer(_settle, () {
        if (mounted) ref.read(localBackupProvider.notifier).runIfDue();
      });
    } finally {
      _checking = false;
    }
  }

  Future<void> _offerRestore() async {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final go = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('local_backup_restore_offer_title'),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('local_backup_restore_offer_body'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(sheet).pop(true),
                  child: Text(tr('local_backup_restore_now')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(sheet).pop(false),
                  child: Text(tr('local_backup_not_now')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (go == true && mounted) await startLocalBackupRestore(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
