import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Forward picker — bottom sheet (same pattern as wall forward).
Future<void> showForwardSheet(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ChatForwardSheet(message: message),
  );
}

class _ChatForwardSheet extends ConsumerStatefulWidget {
  const _ChatForwardSheet({required this.message});

  final ChatMessage message;

  @override
  ConsumerState<_ChatForwardSheet> createState() => _ChatForwardSheetState();
}

class _ChatForwardSheetState extends ConsumerState<_ChatForwardSheet> {
  final _selected = <String>{};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final targets = [
      ...chat.channels,
      ...chat.dms,
    ].where((c) => c.id != widget.message.conversationId).toList();
    final colors = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const Expanded(
                      child: Text(
                        'Forward message',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: _sending || _selected.isEmpty
                          ? null
                          : _forward,
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _selected.isEmpty
                                  ? 'Forward'
                                  : 'Forward (${_selected.length})',
                            ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: targets.isEmpty
                    ? Center(
                        child: Text(
                          'No other conversations to forward to.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: targets.length,
                        itemBuilder: (_, i) {
                          final c = targets[i];
                          final checked = _selected.contains(c.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: _sending
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selected.add(c.id);
                                      } else {
                                        _selected.remove(c.id);
                                      }
                                    });
                                  },
                            title: Text(c.displayTitle(chat.currentUserId)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forward() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(chatProvider.notifier)
          .forwardMessage(
            messageId: widget.message.id,
            conversationIds: _selected.toList(),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
