import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/chat_conversation.dart';
import '../providers/chat_provider.dart';

/// The reference app's message-request prompt: it takes the composer's place at
/// the bottom of a thread a stranger opened, so the messages above stay
/// readable while the answer is still owed.
///
/// Three answers, and only one of them is permanent. Block is the durable
/// refusal; Delete just clears the thread, and a later message from the same
/// person opens a fresh request. Accept settles it — as does simply replying,
/// which the server does on its own.
class MessageRequestBar extends ConsumerStatefulWidget {
  const MessageRequestBar({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<MessageRequestBar> createState() => _MessageRequestBarState();
}

class _MessageRequestBarState extends ConsumerState<MessageRequestBar> {
  bool _busy = false;

  String get _peerName =>
      widget.conversation.peerUserName?.trim().isNotEmpty == true
      ? widget.conversation.peerUserName!.trim()
      : AppTranslations.translate(context, ref, 'chat_someone');

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // The list refreshes from the server either way; a failed tap leaves the
      // bar in place, which is the honest outcome.
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final notifier = ref.read(chatProvider.notifier);
    final id = widget.conversation.id;
    final peerId = widget.conversation.peerUserId ?? '';

    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('chat_request_prompt').replaceFirst('{name}', _peerName),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: peerId.isEmpty
                          ? null
                          : () => _run(() => notifier.blockPeer(id, peerId)),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      child: Text(tr('chat_request_block')),
                    ),
                    TextButton(
                      onPressed: () => _run(() => notifier.hideDm(id)),
                      child: Text(tr('chat_request_delete')),
                    ),
                    FilledButton(
                      onPressed: () =>
                          _run(() => notifier.acceptMessageRequest(id)),
                      child: Text(tr('chat_request_accept')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
