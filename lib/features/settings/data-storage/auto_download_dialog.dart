import 'package:flutter/material.dart';

import '../../../core/network/network_class.dart';
import '../../attachments/auto_download/auto_download_settings.dart';

/// Signal's multi-select: which connections this kind of media may download
/// on, all at once rather than three separate rows.
///
/// Returns null when dismissed, so "cleared every box" stays distinguishable
/// from "changed nothing".
Future<Set<AutoDownloadNetwork>?> showAutoDownloadDialog(
  BuildContext context, {
  required AutoDownloadMedia media,
  required Set<AutoDownloadNetwork> selected,
}) => showDialog<Set<AutoDownloadNetwork>>(
  context: context,
  builder: (_) => _AutoDownloadDialog(media: media, selected: selected),
);

class _AutoDownloadDialog extends StatefulWidget {
  const _AutoDownloadDialog({required this.media, required this.selected});

  final AutoDownloadMedia media;
  final Set<AutoDownloadNetwork> selected;

  @override
  State<_AutoDownloadDialog> createState() => _AutoDownloadDialogState();
}

class _AutoDownloadDialogState extends State<_AutoDownloadDialog> {
  late final Set<AutoDownloadNetwork> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.media.label),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final network in AutoDownloadNetwork.values)
              CheckboxListTile(
                value: _selected.contains(network),
                title: Text(network.label),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _selected.add(network);
                  } else {
                    _selected.remove(network);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
