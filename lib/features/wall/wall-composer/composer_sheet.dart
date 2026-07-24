import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/wall_models.dart';
import '../providers/wall_provider.dart';
import '../wall_utils.dart';
import 'composer_toolbar.dart';

Future<void> showWallComposerSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isPremium,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => WallComposerSheet(isPremium: isPremium),
  );
}

class WallComposerSheet extends ConsumerStatefulWidget {
  const WallComposerSheet({super.key, required this.isPremium});
  final bool isPremium;

  @override
  ConsumerState<WallComposerSheet> createState() => _WallComposerSheetState();
}

class _WallComposerSheetState extends ConsumerState<WallComposerSheet> {
  final _ctrl = TextEditingController();
  final _mentions = <String>{};
  final _pending = <WallAttachmentInput>[];
  String? _category;
  var _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plain = _ctrl.text.trim();
    if ((plain.isEmpty && _pending.isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(wallProvider.notifier).createPost(
            body: wallBodyForApi(plain.isEmpty ? ' ' : plain),
            category: _category,
            attachments: _pending.isEmpty ? null : _pending,
            mentionedUserIds: _mentions.isEmpty ? null : _mentions.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(wallProvider).categories;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create post',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Share an update…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (cats.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final c in cats)
                  DropdownMenuItem(value: c.slug, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < _pending.length; i++)
                  Chip(
                    label: Text(_pending[i].fileName),
                    onDeleted: () => setState(() => _pending.removeAt(i)),
                  ),
              ],
            ),
          ],
          WallComposerActions(
            busy: _busy,
            isPremium: widget.isPremium,
            onMentioned: (id, name) {
              setState(() {
                _mentions.add(id);
                _ctrl.text = '${_ctrl.text}@$name '.trimLeft();
                _ctrl.selection = TextSelection.collapsed(
                  offset: _ctrl.text.length,
                );
              });
            },
            onAttached: (a) => setState(() => _pending.add(a)),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
