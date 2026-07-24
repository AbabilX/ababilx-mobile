import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/network/api_client.dart';
import '../messages/chat_icon.dart';
import 'data/models/workspace_search_hit.dart';
import 'data/search_api.dart';

/// Web Cmd+K — team-wide realtime search (DM / channel / wall / task).
void openWorkspaceSearch(BuildContext context, WidgetRef ref) {
  showSearch<void>(
    context: context,
    delegate: WorkspaceSearchDelegate(ref),
  );
}

class WorkspaceSearchDelegate extends SearchDelegate<void> {
  WorkspaceSearchDelegate(this.ref)
      : super(searchFieldLabel: 'Search messages, wall, tasks…');

  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) =>
      _WorkspaceSearchBody(query: query, ref: ref, onOpen: _open);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _WorkspaceSearchBody(query: query, ref: ref, onOpen: _open);

  void _open(BuildContext context, WorkspaceSearchHit hit) {
    close(context, null);
    switch (hit.source) {
      case 'dm':
      case 'channel':
        final id = hit.conversationId;
        if (id != null && id.isNotEmpty) {
          context.push('/messages/$id');
        }
      case 'wall_post':
      case 'wall_comment':
        final id = hit.postId;
        if (id != null && id.isNotEmpty) {
          context.push('/wall/post/$id');
        }
      case 'task':
      case 'task_comment':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Board tasks are not available on mobile yet'),
          ),
        );
      default:
        break;
    }
  }
}

class _WorkspaceSearchBody extends StatefulWidget {
  const _WorkspaceSearchBody({
    required this.query,
    required this.ref,
    required this.onOpen,
  });

  final String query;
  final WidgetRef ref;
  final void Function(BuildContext context, WorkspaceSearchHit hit) onOpen;

  @override
  State<_WorkspaceSearchBody> createState() => _WorkspaceSearchBodyState();
}

class _WorkspaceSearchBodyState extends State<_WorkspaceSearchBody> {
  Timer? _debounce;
  var _req = 0;
  List<WorkspaceSearchHit> _hits = const [];
  var _loading = false;
  String? _error;
  var _gated = false;

  @override
  void initState() {
    super.initState();
    _runSearch(widget.query);
  }

  @override
  void didUpdateWidget(_WorkspaceSearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _runSearch(widget.query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _runSearch(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _loading = false;
        _error = null;
        _gated = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _gated = false;
    });
    final myReq = ++_req;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final api = WorkspaceSearchApi(widget.ref.read(apiClientProvider));
        final hits = await api.search(q);
        if (!mounted || myReq != _req) return;
        setState(() {
          _hits = hits;
          _loading = false;
          _error = null;
          _gated = false;
        });
      } catch (e) {
        if (!mounted || myReq != _req) return;
        final msg = extractApiError(e);
        setState(() {
          _hits = const [];
          _loading = false;
          _gated = msg == 'premium_required' || msg == 'ai_disabled';
          _error = _gated ? null : msg;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final q = widget.query.trim();
    if (q.length < 2) {
      return Center(
        child: Text(
          'Type at least 2 characters',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }
    if (_loading && _hits.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_gated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Workspace search needs Solo Premium (same as web ⌘K).',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_hits.isEmpty) {
      return const Center(child: Text('No results'));
    }
    return ListView.separated(
      itemCount: _hits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final hit = _hits[i];
        return ListTile(
          title: Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            hit.snippet.isNotEmpty ? hit.snippet : hit.authorName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            hit.typeBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          onTap: () => widget.onOpen(context, hit),
        );
      },
    );
  }
}
