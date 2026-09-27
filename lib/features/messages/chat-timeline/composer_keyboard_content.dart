import 'package:flutter/services.dart';

import '../../../shared/media/picked_media_file.dart';

/// What the chat field tells the keyboard it accepts.
///
/// Gboard, Samsung Keyboard and SwiftKey hand a sticker or a GIF over as a
/// file through Android's commit-content API. A field that declares no
/// handler gets "AbabilX doesn't support image insertion here" instead, which
/// is what people were hitting. Images only: every keyboard sends its GIFs as
/// `image/gif` and its stickers as PNG or WebP.
const keyboardContentMimeTypes = <String>[
  'image/gif',
  'image/webp',
  'image/png',
  'image/jpeg',
  'image/jpg',
];

/// The inserted item as a file the ordinary upload path takes, or null when
/// the keyboard sent no bytes (a revoked grant) or something not an image.
///
/// The name comes from the keyboard's URI when it carries a usable one, so a
/// GIF keeps `.gif` and the receiver's type sniffing agrees with the header;
/// otherwise it is made up from the type.
PickedMediaFile? keyboardContentFile(
  KeyboardInsertedContent content, {
  DateTime? now,
}) {
  final bytes = content.data;
  if (bytes == null || bytes.isEmpty) return null;
  final mime = _normalMime(content.mimeType);
  if (!keyboardContentMimeTypes.contains(mime)) return null;
  return PickedMediaFile(
    bytes: bytes,
    fileName: _fileName(content.uri, mime, now ?? DateTime.now()),
    contentType: mime == 'image/jpg' ? 'image/jpeg' : mime,
  );
}

String _normalMime(String mime) => mime.split(';').first.trim().toLowerCase();

String _fileName(String uri, String mime, DateTime now) {
  final ext = _extFor(mime);
  final last = Uri.tryParse(uri)?.pathSegments.lastOrNull ?? '';
  final safe = RegExp(r'^[A-Za-z0-9._-]{1,80}$');
  if (safe.hasMatch(last) && last.toLowerCase().endsWith('.$ext')) return last;
  final kind = mime == 'image/gif' ? 'gif' : 'sticker';
  return '$kind-${now.millisecondsSinceEpoch}.$ext';
}

String _extFor(String mime) => switch (mime) {
  'image/gif' => 'gif',
  'image/webp' => 'webp',
  'image/png' => 'png',
  _ => 'jpg',
};
