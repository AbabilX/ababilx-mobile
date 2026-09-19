import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/data/models/media_dimensions.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';

/// Chooses a media tile's shape once, when it mounts, and holds it.
///
/// A mounted tile must never change height. In a `reverse: true` list the rows
/// below the viewport are laid out first, so a row there growing — a photo
/// finishing its decode, a download landing — shoves every visible row up.
/// That was the jitter scrolling down to newer messages, and the list
/// "bouncing back up" before the newest message could be reached. A shape
/// learned after mount waits for the next mount, which happens off screen and
/// inserts the row at its new height without moving anything on screen.
///
/// The shape comes from `AttachmentHandleMemory`, which is filled before rows
/// mount (feed warm-up, earlier resolves, finished downloads), so almost every
/// tile mounts already knowing it.
mixin MediaFrameLock<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The attachment whose shape is locked.
  ChatMessageAttachment get framedAttachment;

  MediaDimensions? _locked;
  String? _lockedUrl;

  /// Null when the shape was unknown at mount: the tile keeps its default
  /// frame until it is next mounted.
  MediaDimensions? get lockedDimensions => _locked;

  @override
  void initState() {
    super.initState();
    _lock();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same element handed a different attachment is a different tile.
    if (framedAttachment.fileUrl != _lockedUrl) _lock();
  }

  void _lock() {
    final memory = ref.read(attachmentHandleMemoryProvider);
    _lockedUrl = framedAttachment.fileUrl;
    _locked = memory.dimensionsOf(memory.urlKeyOf(_lockedUrl!));
  }
}
