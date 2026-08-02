import 'package:flutter/material.dart';

import '../models/device_model.dart';
import '../models/file_dto.dart';

/// Accept/decline prompt shown when a peer requests to send files.
class IncomingRequestDialog extends StatelessWidget {
  const IncomingRequestDialog({
    super.key,
    required this.peer,
    required this.files,
  });

  final LocalDevice peer;
  final List<LocalFileDto> files;

  static Future<bool> show(
    BuildContext context, {
    required LocalDevice peer,
    required List<LocalFileDto> files,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncomingRequestDialog(peer: peer, files: files),
    );
    return result ?? false;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);

    return AlertDialog(
      title: Text('${peer.alias} wants to send files'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${files.length} file${files.length == 1 ? '' : 's'} · ${_formatSize(totalSize)}'),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    files[i].fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
