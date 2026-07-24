import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/providers/chat_provider.dart';
import '../providers/wall_provider.dart';
import '../providers/wall_ui_provider.dart';

Future<void> showWallForwardSheet(
  BuildContext context,
  WidgetRef ref,
  String postId,
) async {
  final ui = ref.read(wallUiProvider.notifier);
  ui.setForwardSheetOpen(true);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WallForwardSheet(postId: postId),
    );
  } finally {
    ui.setForwardSheetOpen(false);
  }
}

class _WallForwardSheet extends ConsumerStatefulWidget {
  const _WallForwardSheet({required this.postId});

  final String postId;

  @override
  ConsumerState<_WallForwardSheet> createState() => _WallForwardSheetState();
}

class _WallForwardSheetState extends ConsumerState<_WallForwardSheet> {
  final _selected = <String>{};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final targets = [...chat.channels, ...chat.dms];
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
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const Expanded(
                      child: Text(
                        'Forward to chat',
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Send'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: targets.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations yet. Open Messages first.',
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
      await ref.read(wallProvider.notifier).forwardPost(
            postId: widget.postId,
            conversationIds: _selected.toList(),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
