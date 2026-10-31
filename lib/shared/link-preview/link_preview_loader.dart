import 'dart:async';

import 'package:flutter/foundation.dart';

import 'link_preview_cache.dart';
import 'link_preview_data.dart';
import 'link_preview_fetch.dart';
import 'link_preview_image_store.dart';

/// The one entry point a widget calls. Cache first, then one fetch per URL no
/// matter how many bubbles ask at once — a forwarded link in twenty chats is
/// twenty widgets and must not be twenty requests.
final _inFlight = <String, Future<LinkPreviewData?>>{};

Future<LinkPreviewData?> loadLinkPreview(String url) {
  final existing = _inFlight[url];
  if (existing != null) return existing;

  // Block body: `=> _inFlight.remove(url)` hands `request` itself back to
  // whenComplete, which then waits on its own future and never completes.
  final request = _load(url).whenComplete(() {
    _inFlight.remove(url);
  });
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
    // The picture is pulled onto this device rather than left as a URL for an
    // image widget to fetch — the reference app's `fetchThumbnail`, and the
    // only way the og:image gets the same guards the page got.
    PreviewImageFile? image;
    try {
      image = await downloadPreviewImage(preview.imageUrl!);
    } catch (error) {
      // Named for the same reason the unfurl's failure is: a card that lost its
      // picture and a page that never had one look identical on screen.
      debugPrint('[link-preview] could not download image for $url: $error');
    }
    preview = preview.withImage(image?.path, image?.width, image?.height);
    // `isEmpty` cannot answer this: it asks what the PAGE offered, and the
    // page still offers an og:image URL that would not download. A card whose
    // only content was that picture has nothing left to say.
    if (image == null && (preview.title ?? '').isEmpty) preview = null;
  }

  await LinkPreviewCache.instance.write(url, preview);
  return preview;
}
