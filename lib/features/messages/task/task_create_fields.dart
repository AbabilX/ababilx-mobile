import 'package:flutter/material.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../../../shared/widgets/app_capsule.dart';
import 'task_card_data.dart';
import 'task_icons.dart';
import 'task_palette.dart';
import 'task_strings.dart';

InputDecoration taskFieldDecoration(BuildContext context, {String? hint}) {
  final colors = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    border: border(colors.outlineVariant),
    enabledBorder: border(colors.outlineVariant),
    focusedBorder: border(colors.primary),
  );
}

/// The four priorities as capsules; the picked one takes its own tint.
class TaskPriorityPicker extends StatelessWidget {
  const TaskPriorityPicker({
    super.key,
    required this.value,
    required this.strings,
    required this.onChanged,
  });

  final TaskPriority value;
  final TaskStrings strings;
  final ValueChanged<TaskPriority>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = TaskPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in TaskPriority.values)
          AppCapsule(
            label: strings.priorityName(p),
            icon: TaskIcons.priority(p),
            tint: palette.priority(p),
            selected: p == value,
            onTap: onChanged == null ? null : () => onChanged!(p),
          ),
      ],
    );
  }
}

/// Files added to the task so far, each a capsule with its own remove.
class TaskFileChips extends StatelessWidget {
  const TaskFileChips({super.key, required this.files, this.onRemove});

  final List<ChatAttachmentInput> files;
  final ValueChanged<ChatAttachmentInput>? onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final file in files)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: AppCapsule(
            label: file.fileName,
            icon: file.contentType.startsWith('image/')
                ? TaskIcons.photo
                : TaskIcons.file,
            onTap: onRemove == null ? null : () => onRemove!(file),
            trailing: onRemove == null
                ? null
                : const ChatIcon(TaskIcons.remove, size: 16),
          ),
        ),
    ],
  );
}

/// Title, then the description under it.
class TaskTextFields extends StatelessWidget {
  const TaskTextFields({
    super.key,
    required this.title,
    required this.description,
    required this.strings,
    required this.enabled,
  });

  final TextEditingController title;
  final TextEditingController description;
  final TaskStrings strings;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: title,
        enabled: enabled,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: taskFieldDecoration(context, hint: strings.titleLabel),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: description,
        enabled: enabled,
        minLines: 4,
        maxLines: 10,
        textCapitalization: TextCapitalization.sentences,
        decoration: taskFieldDecoration(context, hint: strings.descriptionHint),
      ),
    ],
  );
}
