import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../messages/chat-timeline/pending_preview_cache.dart';
import '../messages/chat_icon.dart';
import '../messages/data/models/chat_models.dart';

/// What is about to be sent, one page per attachment. Drawn from the local
/// file the review screen produced — the upload may still be running, and
/// fetching the object back would be a download of our own photo.
class PrivacyMediaPager extends StatefulWidget {
  const PrivacyMediaPager({super.key, required this.attachments});

  final List<ChatAttachmentInput> attachments;

  @override
  State<PrivacyMediaPager> createState() => _PrivacyMediaPagerState();
}

class _PrivacyMediaPagerState extends State<PrivacyMediaPager> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.attachments;
    return Stack(
      children: [
        PageView.builder(
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => _Page(attachment: items[i]),
        ),
        if (items.length > 1)
          Positioned(
            top: 12,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  '${_page + 1} / ${items.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.attachment});

  final ChatAttachmentInput attachment;

  @override
  Widget build(BuildContext context) {
    final path = PendingPreviewCache.get(attachment.fileUrl);
    final image = looksLikeImage(attachment.contentType, attachment.fileName);
    if (image && path != null) {
      final width =
          MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context);
      return Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          cacheWidth: width.round(),
          errorBuilder: (_, _, _) => _FileCard(attachment: attachment),
        ),
      );
    }
    return _FileCard(attachment: attachment);
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.attachment});

  final ChatAttachmentInput attachment;

  @override
  Widget build(BuildContext context) {
    final video = attachment.contentType.startsWith('video/');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatIcon(
            video
                ? HugeIcons.strokeRoundedVideo01
                : HugeIcons.strokeRoundedFile01,
            size: 72,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              attachment.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
