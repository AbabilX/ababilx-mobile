import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_capsule.dart';
import '../chat-pins/pinned_messages_chrome.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_details_provider.dart';
import 'snippet_card.dart';
import 'snippet_format.dart';
import 'snippet_strings.dart';

/// Every snippet sent in one chat, newest first. Tapping a card opens the
/// whole file, as it does in the timeline.
///
/// There is no snippet list on the server: a snippet is a `.md` / `.txt`
/// file, so this pages the chat's shared files and keeps those. A page can
/// hold none, so loading goes on until a screenful is found or the files end.
class SnippetListScreen extends ConsumerStatefulWidget {
  const SnippetListScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<SnippetListScreen> createState() => _SnippetListState();
}

class _SnippetListState extends ConsumerState<SnippetListScreen> {
  static const _screenful = 8;
  static const _maxEmptyPages = 10;

  final List<ChatMessageAttachment> _items = [];
  String _cursor = '';
  bool _hasMore = true;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final wanted = _items.length + _screenful;
    try {
      for (var pages = 0; pages < _maxEmptyPages; pages++) {
        final page = await ref.read(sharedMediaLoadProvider)(
          widget.conversationId,
          kind: 'files',
          cursor: _cursor,
          limit: 60,
        );
        if (!mounted) return;
        _items.addAll(
          page.items.where((a) => isSnippetFile(a.fileName, a.sizeBytes)),
        );
        _cursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor.isNotEmpty;
        if (!_hasMore || _items.length >= wanted) break;
      }
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.pixels > metrics.maxScrollExtent - 600) _load();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = SnippetStrings.of(ref.watch(appLanguageProvider));
    final padding = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: padding.top + 64),
              child: _body(s, padding.bottom),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PinnedMessagesTopBar(title: s.snippets, bottomPadding: 12),
          ),
        ],
      ),
    );
  }

  Widget _body(SnippetStrings s, double bottom) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _Notice(
        title: _failed ? s.listFailed : s.listEmptyTitle,
        body: _failed ? null : s.listEmptyBody,
        // Stopped looking with files still unread: let the search go on.
        action: _failed || _hasMore
            ? AppCapsule(label: _failed ? s.retry : s.loadMore, onTap: _load)
            : null,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 24),
        itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        // The last row: a spinner while reading, else the way to read on —
        // a short list cannot be scrolled to ask for more.
        itemBuilder: (_, index) => index >= _items.length
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : AppCapsule(label: s.loadMore, onTap: _load),
                ),
              )
            : SnippetCard(
                key: ValueKey(_items[index].id),
                attachment: _items[index],
                fill: true,
              ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, this.body, this.action});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
