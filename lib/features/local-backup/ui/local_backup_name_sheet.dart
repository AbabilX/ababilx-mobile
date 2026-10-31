import 'package:flutter/material.dart';

import '../data/backup_file_name.dart';

/// The backup file's name, on a bottom sheet. The cleaned name, empty to go
/// back to the automatic one, or null when dismissed.
Future<String?> showBackupNameSheet(
  BuildContext context, {
  required String current,
  required String title,
  required String hint,
  required String placeholder,
  required String saveLabel,
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _BackupNameSheet(
    current: current,
    title: title,
    hint: hint,
    placeholder: placeholder,
    saveLabel: saveLabel,
  ),
);

class _BackupNameSheet extends StatefulWidget {
  const _BackupNameSheet({
    required this.current,
    required this.title,
    required this.hint,
    required this.placeholder,
    required this.saveLabel,
  });

  final String current;
  final String title;
  final String hint;
  final String placeholder;
  final String saveLabel;

  @override
  State<_BackupNameSheet> createState() => _BackupNameSheetState();
}

class _BackupNameSheetState extends State<_BackupNameSheet> {
  late final _field = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final clean = cleanBackupName(_field.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.hint,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _field,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: widget.placeholder),
              ),
              const SizedBox(height: 8),
              Text(
                backupFileName(
                  widget.placeholder,
                  DateTime.now(),
                  customName: clean,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.of(context).pop(clean),
                child: Text(widget.saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
