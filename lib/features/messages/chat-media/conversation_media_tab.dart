import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-timeline/attachment_file_row.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_details_provider.dart';
import 'shared_media_thumb.dart';
import '../../chat-lock/media/ram_file_row.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';

/// One tab of the shared-media screen, paging as it is scrolled.
///
/// Paging state is held here rather than in a provider: the list is read once,
/// scrolled, and thrown away when the screen closes, so a provider would only
/// add a cache nobody reads back.
class ConversationMediaTab extends ConsumerStatefulWidget {
  const ConversationMediaTab({
    super.key,
    required this.conversationId,
    required this.kind,
  });

  final String conversationId;

  /// `media` (pictures and video) or `files` (everything else).
  final String kind;

  @override
  ConsumerState<ConversationMediaTab> createState() =>
      _ConversationMediaTabState();
}

class _ConversationMediaTabState extends ConsumerState<ConversationMediaTab>
    with AutomaticKeepAliveClientMixin {
  final List<ChatMessageAttachment> _items = [];
  String _cursor = '';
  bool _hasMore = true;
  bool _loading = false;
  String _error = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final page = await ref
          .read(chatDetailsApiProvider)
          .listMedia(
            widget.conversationId,
            kind: widget.kind,
            cursor: _cursor,
            limit: 60,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        // Stopping on an empty cursor as well as on has_more keeps a server
        // that cannot produce one from turning this into an endless refetch.
        _hasMore = page.hasMore && page.nextCursor.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.pixels > metrics.maxScrollExtent - 600) _load();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error.isNotEmpty
                ? _error
                : widget.kind == 'media'
                ? 'No photos or videos yet'
                : 'No files yet',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // A locked chat draws from memory only (see RamMessageAttachments).
    final ramOnly = ref.watch(isChatLockedProvider(widget.conversationId));
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.kind == 'media' ? _grid(ramOnly) : _files(ramOnly),
    );
  }

  Widget _grid(bool ramOnly) {
    const spacing = 3.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - spacing * 2) / 3;
        // Videos open their own player, so the swipe gallery is pictures only.
        final gallery = _items.where((a) => a.isImage).toList();
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
          itemCount: _items.length,
          itemBuilder: (_, i) => SharedMediaThumb(
            attachment: _items[i],
            gallery: gallery,
            size: cell,
            ramOnly: ramOnly,
          ),
        );
      },
    );
  }

  Widget _files(bool ramOnly) => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: _items.length,
    itemBuilder: (_, i) => ramOnly
        ? RamFileRow(attachment: _items[i])
        : AttachmentFileRow(attachment: _items[i]),
  );
}
