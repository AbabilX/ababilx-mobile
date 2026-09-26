import 'package:flutter/material.dart';

import '../../attachments/widgets/attachment_gate.dart';
import '../../messages/chat-timeline/attachment_gallery.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/khaam_payload.dart';

/// The memory photo riding on a Khaam's message, or null when it has none
/// (or it has not arrived with the message).
ChatMessageAttachment? khaamPhotoOf(ChatMessage message, KhaamPayload payload) {
  final name = payload.photo;
  if (name == null) return null;
  for (final a in message.attachments) {
    if (a.fileName == name) return a;
  }
  return null;
}

/// The memory, drawn from this phone's copy through the ordinary attachment
/// gate — so it downloads, caches and retries like any chat photo. [open]
/// makes a tap show it full screen; off while it is still under the foil.
class KhaamPhoto extends StatelessWidget {
  const KhaamPhoto({
    super.key,
    required this.attachment,
    required this.width,
    required this.height,
    this.radius = 16,
    this.open = true,
  });

  final ChatMessageAttachment attachment;
  final double width;
  final double height;
  final double radius;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return AttachmentGate(
      attachment: attachment,
      reserveSpace: true,
      width: width,
      height: height,
      shape: shape,
      showSize: false,
      ready: (context, handle) => ClipRRect(
        borderRadius: shape,
        child: GestureDetector(
          onTap: open
              ? () => showChatAttachmentGallery(
                  context,
                  images: [attachment],
                  index: 0,
                )
              : null,
          child: Image.file(
            handle.file!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                .round(),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
          ),
        ),
      ),
    );
  }
}
