import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/video_thumbnail.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../../profile/data/session_repository.dart';
import '../transfer_chats_service.dart';
import '../transfer_send_session.dart';
import '../wire/transfer_chats_payload.dart';
import 'transfer_chats_copy.dart';
import 'transfer_receive_body.dart';

/// The old phone's side, after it scanned a Transfer chats code: progress,
/// then "Delete chats from this phone?". A bottom sheet that cannot be
/// swiped away while the transfer runs.
Future<void> showTransferSendSheet(
  BuildContext context,
  WidgetRef ref,
  String payload,
) async {
  final code = parseTransferChatsPayload(payload);
  if (code == null) {
    showAppToast(context, transferText(ref, 'error_failed'), isError: true);
    return;
  }
  final session = TransferSendSession(
    service: ref.read(transferChatsServiceProvider),
    vault: ref.read(messageVaultProvider),
    sessions: ref.read(sessionRepositoryProvider),
    userId: await ref.read(chatProvider.notifier).ensureCurrentUserId(),
    code: code,
  );
  unawaited(VideoThumbnails.keepScreenOn(true));
  unawaited(session.run());
  try {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (_) => _SendSheet(session: session),
    );
  } finally {
    session.dispose();
    unawaited(VideoThumbnails.keepScreenOn(false));
  }
}

class _SendSheet extends ConsumerStatefulWidget {
  const _SendSheet({required this.session});
  final TransferSendSession session;

  @override
  ConsumerState<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<_SendSheet> {
  bool _wiping = false;

  Future<void> _wipe() async {
    setState(() => _wiping = true);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    try {
      await ref.read(transferChatsServiceProvider).wipeThisPhone();
      showAppToastIn(overlay, transferText(ref, 'wiped'));
    } catch (_) {
      showAppToastIn(overlay, transferText(ref, 'error_failed'));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => transferText(ref, key);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ValueListenableBuilder<TransferSendState>(
          valueListenable: widget.session.state,
          builder: (context, state, _) {
            final close = TextButton(
              onPressed: () {
                widget.session.cancel();
                Navigator.of(context).pop();
              },
              child: Text(
                t(state.phase == SendPhase.failed ? 'close' : 'cancel'),
              ),
            );
            final children = switch (state.phase) {
              SendPhase.connecting => [
                TransferProgress(text: t('send_connecting')),
                close,
              ],
              SendPhase.sending => [
                TransferProgress(
                  text: t(
                    'send_sending',
                  ).replaceAll('{count}', '${state.sent}'),
                ),
                Text(t('send_keep_open'), style: TextStyle(color: muted)),
                close,
              ],
              SendPhase.waiting => [
                TransferProgress(
                  text: t(
                    'send_waiting',
                  ).replaceAll('{count}', '${state.remote.messages}'),
                ),
                close,
              ],
              SendPhase.failed => [
                Text(t('error_${state.error}'), textAlign: TextAlign.center),
                close,
              ],
              SendPhase.done => [
                Text(t('send_done'), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  t('wipe_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                Text(t('wipe_body'), style: TextStyle(color: muted)),
                FilledButton(
                  onPressed: _wiping ? null : () => Navigator.of(context).pop(),
                  child: Text(t('wipe_keep')),
                ),
                TextButton(
                  onPressed: _wiping ? null : _wipe,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(t('wipe_delete')),
                ),
              ],
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(
                  t('send_title'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                ...children,
              ],
            );
          },
        ),
      ),
    );
  }
}
