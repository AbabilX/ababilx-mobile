import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wall_provider.dart';
import '../wall_utils.dart';

class WallCommentComposer extends ConsumerStatefulWidget {
  const WallCommentComposer({
    super.key,
    required this.postId,
    this.parentId,
  });

  final String postId;
  final String? parentId;

  @override
  ConsumerState<WallCommentComposer> createState() =>
      _WallCommentComposerState();
}

class _WallCommentComposerState extends ConsumerState<WallCommentComposer> {
  final _ctrl = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final plain = _ctrl.text.trim();
    if (plain.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(wallProvider.notifier).addComment(
            widget.postId,
            body: wallBodyForApi(plain),
            parentId: widget.parentId,
          );
      _ctrl.clear();
      ref.invalidate(wallPostProvider(widget.postId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write a comment…',
              isDense: true,
            ),
          ),
        ),
        IconButton(
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
        ),
      ],
    );
  }
}

Future<void> showWallCommentComposer(
  BuildContext context,
  WidgetRef ref, {
  required String postId,
  String? parentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
      ),
      child: WallCommentComposer(postId: postId, parentId: parentId),
    ),
  );
}
