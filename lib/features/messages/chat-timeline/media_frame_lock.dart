import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/data/models/media_dimensions.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';
import 'media_frame_shift.dart';

/// Chooses a media tile's shape when it mounts, and holds it.
///
/// A mounted tile must not change height while that moves what the reader is
/// looking at. In a `reverse: true` list the rows below the viewport are laid
/// out first, so a row there growing — a photo finishing its decode, a
/// download landing — shoves every visible row up. That was the jitter
/// scrolling down to newer messages, and the list "bouncing back up" before
/// the newest message could be reached.
///
/// The shape comes from `AttachmentHandleMemory`, which is filled before rows
/// mount (feed warm-up, earlier resolves, finished downloads), so almost every
/// tile mounts already knowing it. The one that cannot is a photo or video
/// that arrives while the chat is open: it mounts before its bytes exist.
/// Holding the default square until the next mount drew it squashed until the
/// chat was reopened, so a shape learned after mount is taken as soon as
/// [canResizeMediaFrame] says nothing on screen would move.
mixin MediaFrameLock<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The attachment whose shape is locked.
  ChatMessageAttachment get framedAttachment;

  MediaDimensions? _locked;
  String? _lockedUrl;
  MediaDimensions? _pending;
  ProviderSubscription<AsyncValue<AttachmentHandle>>? _handleSub;
  ScrollPosition? _watched;
  bool _checkQueued = false;

  /// Null until the shape is known: the tile keeps its default frame.
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

  @override
  void dispose() {
    _stopWaiting();
    super.dispose();
  }

  void _lock() {
    _stopWaiting();
    final memory = ref.read(attachmentHandleMemoryProvider);
    _lockedUrl = framedAttachment.fileUrl;
    _locked = memory.dimensionsOf(memory.urlKeyOf(_lockedUrl!));
    if (_locked != null) return;
    // Only an unknown shape listens; a known one costs nothing per row.
    _handleSub = ref.listenManual(attachmentHandleProvider(framedAttachment), (
      _,
      next,
    ) {
      final size = next.valueOrNull?.dimensions;
      if (size != null) _offer(size);
    });
    // The handle may already carry a shape the memory has not seen.
    final sub = _handleSub!;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final size = identical(sub, _handleSub)
          ? sub.read().valueOrNull?.dimensions
          : null;
      if (size != null) _offer(size);
    });
  }

  /// Looked up, not depended on: this runs from listeners, never from build.
  ScrollableState? get _scrollable =>
      context.findAncestorStateOfType<ScrollableState>();

  void _offer(MediaDimensions size) {
    if (!mounted) return;
    _handleSub?.close();
    _handleSub = null;
    _pending = size;
    _watched ??= _scrollable?.position
      ?..addListener(_recheck)
      ..isScrollingNotifier.addListener(_recheck);
    _recheck();
  }

  /// Judged after the next layout: a scroll notification arrives before the
  /// rows have moved, so geometry read here would still be the old one.
  void _recheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _checkQueued = false;
        _tryAdopt();
      })
      ..ensureVisualUpdate();
  }

  bool _tryAdopt() {
    final size = _pending;
    if (!mounted || size == null || !_nothingVisibleMoves()) return false;
    _stopWaiting();
    setState(() => _locked = size);
    return true;
  }

  bool _nothingVisibleMoves() {
    final scrollable = _scrollable;
    if (scrollable == null) return true;
    final tile = context.findRenderObject();
    final view = scrollable.context.findRenderObject();
    if (tile is! RenderBox || view is! RenderBox) return false;
    if (!tile.attached || !tile.hasSize || !view.hasSize) return false;
    return canResizeMediaFrame(
      direction: scrollable.axisDirection,
      tile: tile.localToGlobal(Offset.zero) & tile.size,
      viewport: view.localToGlobal(Offset.zero) & view.size,
      scrolling: scrollable.position.isScrollingNotifier.value,
    );
  }

  void _stopWaiting() {
    _handleSub?.close();
    _handleSub = null;
    _pending = null;
    _watched
      ?..removeListener(_recheck)
      ..isScrollingNotifier.removeListener(_recheck);
    _watched = null;
  }
}
