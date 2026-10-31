import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/image_preview_chrome.dart';
import '../../../attachments/widgets/attachment_gate.dart';
import '../../data/models/chat_models.dart';

/// The reference app's album rail: 46dp cells, 8dp corners, the current one
/// ringed.
class ChatMediaPreviewRail extends StatelessWidget {
  const ChatMediaPreviewRail({
    super.key,
    required this.images,
    required this.index,
    required this.onSelect,
  });

  final List<ChatMessageAttachment> images;
  final int index;
  final ValueChanged<int> onSelect;

  static const _size = ImagePreviewChrome.railSize;
  static const _thumb = ImagePreviewChrome.railThumb;

  @override
  Widget build(BuildContext context) {
    if (images.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: images.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: ImagePreviewChrome.railGap),
        itemBuilder: (context, i) {
          final selected = i == index;
          return Semantics(
            button: true,
            selected: selected,
            label: images[i].fileName,
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: SizedBox(
                width: _size,
                height: _size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        ImagePreviewChrome.railRadius,
                      ),
                      child: SizedBox(
                        width: _thumb,
                        height: _thumb,
                        child: AttachmentGate(
                          attachment: images[i],
                          height: _thumb,
                          width: _thumb,
                          showSize: false,
                          ready: (_, handle) => Image.file(
                            File(handle.localPath!),
                            fit: BoxFit.cover,
                            width: _thumb,
                            height: _thumb,
                          ),
                          waiting: (_, _) => const SizedBox.expand(
                            child: ColoredBox(color: Color(0xFF2A2B2E)),
                          ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          ImagePreviewChrome.railRadius,
                        ),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
