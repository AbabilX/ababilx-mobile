import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';

/// "Edit message" as a bottom sheet that rides up with the keyboard. Answers
/// the new text, or null when nothing should be sent — cancelled, swiped
/// away, emptied, or saved unchanged.
Future<String?> showEditMessageSheet(
  BuildContext context,
  WidgetRef ref,
  String initial,
) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditMessageSheet(initial: initial),
  );
}

class _EditMessageSheet extends ConsumerStatefulWidget {
  const _EditMessageSheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends ConsumerState<_EditMessageSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _tr(String key) => AppTranslations.translate(context, ref, key);

  bool get _canSave {
    final value = _text.text.trim();
    return value.isNotEmpty && value != widget.initial.trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tr('chat_edit_message'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 16, height: 1.3),
                  decoration: const InputDecoration(
                    // The app theme fills every field with its own square
                    // plate, which painted over the rounded box behind it.
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_tr('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _canSave
                          ? () => Navigator.of(context).pop(_text.text.trim())
                          : null,
                      icon: const ChatIcon(
                        HugeIcons.strokeRoundedTick02,
                        size: 20,
                      ),
                      label: Text(_tr('chat_save')),
                    ),
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
