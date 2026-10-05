import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/share_thread_queries.dart';
import '../engine/protocol/share_envelope.dart';
import '../share_text.dart';

/// The one-line preview of a thread's last message, shared by the Local Share
/// list and the chat list so the two never word the same thread differently.
String shareThreadPreview(WidgetRef ref, ShareThread thread) {
  final last = thread.last;
  if (last == null) return lsText(ref, 'ls_preview_none');
  final what = switch (last.kind) {
    ShareKind.text => last.text ?? '',
    ShareKind.voice => lsText(ref, 'ls_preview_voice'),
    ShareKind.folder => last.folderName ?? '',
    ShareKind.files when thread.lastFileCount > 1 => lsText(
      ref,
      'ls_folder_files',
      name: '${thread.lastFileCount}',
    ),
    _ => thread.lastFileName ?? '',
  };
  return last.fromMe ? '${lsText(ref, 'ls_you')}: $what' : what;
}
