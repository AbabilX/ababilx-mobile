import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/chat_attachment.dart';

/// Downloads image attachments straight to disk as soon as a message lands
/// (WS push or a fresh fetch), not lazily on first view — so a chat opened
/// offline can still render images it never actually scrolled to.
/// [CachedNetworkImage] reads from this same [DefaultCacheManager] disk
/// store, so a prefetched file is a cache hit with no network call later.
/// Non-image attachments (video/audio/pdf) are streamed on demand and are
/// not prefetched here.
void prefetchImageAttachments(List<ChatMessageAttachment> attachments) {
  for (final a in attachments) {
    if (!a.isImage || a.fileUrl.isEmpty || a.locked) continue;
    unawaited(
      DefaultCacheManager()
          .downloadFile(a.fileUrl)
          .then((_) {})
          .catchError((_) {}),
    );
  }
}
