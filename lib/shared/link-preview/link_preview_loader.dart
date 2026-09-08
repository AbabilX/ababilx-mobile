import 'dart:async';

import 'package:flutter/foundation.dart';

import 'link_preview_cache.dart';
import 'link_preview_data.dart';
import 'link_preview_fetch.dart';
import 'link_preview_image.dart';

/// The one entry point a widget calls. Cache first, then one fetch per URL no
/// matter how many bubbles ask at once — a forwarded link in twenty chats is
/// twenty widgets and must not be twenty requests.
final _inFlight = <String, Future<LinkPreviewData?>>{};

Future<LinkPreviewData?> loadLinkPreview(String url) {
  final existing = _inFlight[url];
  if (existing != null) return existing;

  final request = _load(url).whenComplete(() => _inFlight.remove(url));
  _inFlight[url] = request;
  return request;
}

Future<LinkPreviewData?> _load(String url) async {
  final (known, cached) = await LinkPreviewCache.instance.read(url);
  if (known) return cached;

  LinkPreviewData? preview;
  try {
    preview = await fetchLinkPreview(url);
  } catch (error) {
    // Named, not swallowed. A silent catch is what made a broken metadata
    // source indistinguishable from "this page has no tags" — twice.
    debugPrint('[link-preview] could not unfurl $url: $error');
    preview = null;
  }

  if (preview != null && preview.imageUrl != null) {
    final size = await resolvePreviewImageSize(preview.imageUrl!);
    preview = preview.withImageSize(size?.width.round(), size?.height.round());
  }

  await LinkPreviewCache.instance.write(url, preview);
  return preview;
}
