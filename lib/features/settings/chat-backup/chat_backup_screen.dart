import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/data/device_identity.dart';
import '../../../core/router/root_back.dart';
import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/archive/archive_provider.dart';
import '../settings-hub/settings_row.dart';
import 'chat_backup_actions.dart';
import 'chat_backup_status_card.dart';

/// Chat backup: the encrypted copy of this phone's history.
///
/// The screen states the trade plainly rather than burying it. The server keeps
/// six months; this phone keeps far more; and nothing but this backup survives
/// losing the phone. See CHAT_RETENTION.md.
class ChatBackupScreen extends ConsumerStatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  ConsumerState<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends ConsumerState<ChatBackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(archiveProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGoHome(context),
        ),
        title: const Text('Chat backup'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ChatBackupStatusCard(state: state),
            if (state.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  state.error,
                  style: TextStyle(color: colors.error, fontSize: 13),
                ),
              ),
            const Divider(height: 24),
            ChatBackupActions(
              busy: state.busy,
              canRestore: state.remote != null,
              onBackUp: () => backUpNow(context, ref),
              onRestore: () => restoreNow(context, ref),
            ),
            const Divider(height: 24),
            if (state.remote != null)
              SettingsRow(
                icon: const [],
                title: 'Stored size',
                value: formatBytes(state.remote!.totalBytes),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'The backup is encrypted with a key only your devices hold. '
                'AbabilX cannot read it, and cannot restore it for you if you '
                'lose both your phone and your recovery code.',
                style: TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runs a backup and reports the outcome where the user is looking.
///
/// The device id is the messaging device identity the account already
/// registered, so an archive says which phone wrote it without inventing a
/// second notion of device.
Future<void> backUpNow(BuildContext context, WidgetRef ref) async {
  final deviceId = await DeviceIdentity.get();
  if (!context.mounted) return;
  final ok = await ref
      .read(archiveProvider.notifier)
      .backUp(deviceId: deviceId, nowMs: DateTime.now().millisecondsSinceEpoch);
  if (!context.mounted) return;
  showAppToast(context, ok ? 'Backup complete' : 'Backup failed', isError: !ok);
}

/// Confirms before restoring, because a restore writes into the history that
/// is already on screen. It merges rather than replaces, so nothing is lost —
/// but a user who expected a wipe should not be surprised either way.
Future<void> restoreNow(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Restore backup?'),
      content: const Text(
        'Messages from the backup are added to what is already on this phone. '
        'Nothing already here is removed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Restore'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final restored = await ref.read(archiveProvider.notifier).restore();
  if (!context.mounted) return;
  showAppToast(
    context,
    restored == null ? 'Restore failed' : 'Restored $restored messages',
    isError: restored == null,
  );
}
