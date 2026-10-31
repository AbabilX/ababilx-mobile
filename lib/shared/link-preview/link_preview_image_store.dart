/// Downloads a preview picture onto this device — the reference Android app's
/// `LinkPreviewRepository.fetchThumbnail`, ported.
///
/// **Why the bytes are fetched rather than the URL handed to an image widget.**
/// The reference app never lets the renderer touch a remote address: the
/// thumbnail is pulled through the same guarded client as the page, decoded,
/// and filed as a local attachment. Pointing `CachedNetworkImage` at an
/// `og:image` instead gives that up three times over — the URL skips
/// `isValidPreviewUrl` (so a page could aim it at a printer on the LAN), the
/// request leaves with the image loader's own headers instead of the crawler
/// user agent, and every device re-fetches it from the host on every cold
/// start.
///
/// What is NOT ported is the reference app's re-encode: it recompresses to fit
/// `PushMediaConstraints` because the thumbnail is about to be SENT. Ours is
/// only ever drawn here, so the bytes are kept as they arrived, capped.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'link_preview_fetch.dart';

/// The reference desktop app's `VALID_IMAGE_MIME_TYPES`. Anything else claiming
/// to be an image is refused before a byte of it is decoded.
const _imageMimes = <String>{
  'image/gif',
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/x-icon',
  'image/vnd.microsoft.icon',
};

/// The reference desktop app's `MIN_IMAGE_CONTENT_LENGTH`: below this there is
/// no image, only an empty body wearing an image content type.
const _minImageBytes = 8;

/// The metadata cache holds 200 entries, so the folder holds 200 files. They
/// are pruned independently — a file is deleted for being old, not for being
/// unreferenced — because a cache entry outliving its picture costs one blank
/// image and a picture outliving its entry costs a few kilobytes.
const _maxStoredImages = 200;

const _folder = 'link_previews';

/// A downloaded preview picture: where it landed and how big it really is.
class PreviewImageFile {
  const PreviewImageFile(this.path, this.width, this.height);

  final String path;
  final int width;
  final int height;
}

/// Returns null whenever the picture cannot be had. A card with a title and no
/// image is a card; a card is never withheld over its picture.
Future<PreviewImageFile?> downloadPreviewImage(
  String url, {
  Dio? client,
}) async {
  final opened = await openPreviewStream(
    url,
    accept: 'image/*',
    client: client,
  );
  if (opened == null) return null;

  final contentType = previewContentType(opened.response);
  if (!_imageMimes.contains(contentType)) {
    await drainPreviewBody(opened.response);
    return null;
  }

  final bytes = await readCappedBody(opened.response, maxPreviewImageBytes);
  if (bytes.length < _minImageBytes) return null;

  // The decode is also the last check that this is an image at all — a content
  // type is a claim by the same host that wrote the link.
  final size = await measurePreviewImage(bytes);
  if (size == null) return null;

  final path = await _store(url, bytes, contentType);
  if (path == null) return null;
  return PreviewImageFile(path, size.width.round(), size.height.round());
}

/// Reads a picture's real dimensions from its header, without decoding pixels.
///
/// The card's layout turns on them (`isBigImagePreview`), and they are resolved
/// once here rather than in `build`: the reference app gets them free because
/// the SENDER attached the thumbnail, and measuring in the widget draws the
/// small card first and snaps to the big one a frame later, on every scroll
/// past.
Future<ui.Size?> measurePreviewImage(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

Future<String?> _store(String url, Uint8List bytes, String contentType) async {
  try {
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/$_folder',
    );
    await directory.create(recursive: true);
    // Named for the URL, so the same picture in twenty chats is one file and a
    // second unfurl of the same link overwrites rather than accumulates.
    final name = sha1.convert(url.codeUnits).toString();
    final file = File('${directory.path}/$name.${_extension(contentType)}');
    await file.writeAsBytes(bytes, flush: true);
    await _prune(directory);
    return file.path;
  } catch (_) {
    // No writable storage is a card without a picture, never a lost card.
    return null;
  }
}

String _extension(String contentType) => switch (contentType) {
  'image/png' => 'png',
  'image/gif' => 'gif',
  'image/webp' => 'webp',
  'image/x-icon' || 'image/vnd.microsoft.icon' => 'ico',
  _ => 'jpg',
};

Future<void> _prune(Directory directory) async {
  try {
    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    if (files.length <= _maxStoredImages) return;
    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    for (final file in files.take(files.length - _maxStoredImages)) {
      await file.delete();
    }
  } catch (_) {
    // A folder that cannot be pruned still serves every picture in it.
  }
}
