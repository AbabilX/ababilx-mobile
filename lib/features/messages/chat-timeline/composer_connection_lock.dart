import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_conversation.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';

/// Locked DM composer: copy and actions follow the server's `lock_reason`.
class ComposerConnectionLock extends ConsumerStatefulWidget {
  const ComposerConnectionLock({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<ComposerConnectionLock> createState() =>
      _ComposerConnectionLockState();
}

class _ComposerConnectionLockState
    extends ConsumerState<ComposerConnectionLock> {
  bool _busy = false;

  String get _peerName {
    final name = widget.conversation.peerUserName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return AppTranslations.translate(context, ref, 'chat_someone');
  }

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _requestConnect() async {
    final peerId = widget.conversation.peerUserId ?? '';
    if (_busy || peerId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(chatConnectionsProvider.notifier).sendRequest(peerId);
      await ref.read(chatProvider.notifier).fetchSidebarSilent();
    } catch (error) {
      if (!mounted) return;
      final code = serverErrorCode(error);
      final message = code == 'request_rejected_cooldown'
          ? _tr('chat_lock_try_later')
          : code == 'request_already_pending'
          ? (serverErrorMessage(error) ?? _tr('chat_lock_reconnect_sent').replaceFirst('{name}', _peerName))
          : (serverErrorMessage(error) ?? friendlyErrorMessage(error));
      showAppToast(context, message, isError: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = widget.conversation.lockReason;
    final name = _peerName;
    final showRequest = reason == 'connection_removed';
    final body = switch (reason) {
      'connection_removed' =>
        _tr('chat_lock_removed').replaceFirst('{name}', name),
      'reconnect_requested' =>
        _tr('chat_lock_reconnect_sent').replaceFirst('{name}', name),
      'account_deleted' => _tr('chat_lock_account_deleted'),
      _ => _tr('chat_connection_required'),
    };

    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (showRequest) ...[
                const SizedBox(height: 12),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else
                  FilledButton(
                    onPressed: _requestConnect,
                    child: Text(_tr('chat_lock_request_connect')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
