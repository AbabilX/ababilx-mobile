import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/network/api_client.dart';
import '../messages/chat_icon.dart';
import 'data/models/crm_search_hit.dart';
import 'data/search_api.dart';

/// CRM deep search — contacts / follow-ups / notes / activities / timeline.
void openCrmDeepSearch(BuildContext context, WidgetRef ref) {
  showSearch<void>(context: context, delegate: CrmDeepSearchDelegate(ref));
}

class CrmDeepSearchDelegate extends SearchDelegate<void> {
  CrmDeepSearchDelegate(this.ref) : super(searchFieldLabel: 'Search CRM…');

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
      _CrmDeepSearchBody(query: query, ref: ref, onOpen: _open);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _CrmDeepSearchBody(query: query, ref: ref, onOpen: _open);

  void _open(BuildContext context, CrmSearchHit hit) {
    close(context, null);
    switch (hit.kind) {
      case 'followup':
        context.push('/crm/followups/${hit.id}');
      case 'contact':
        context.push('/crm/contacts/${hit.id}');
      default:
        if (hit.contactId.isNotEmpty) {
          context.push('/crm/contacts/${hit.contactId}');
        }
    }
  }
}

class _CrmDeepSearchBody extends StatefulWidget {
  const _CrmDeepSearchBody({
    required this.query,
    required this.ref,
    required this.onOpen,
  });

  final String query;
  final WidgetRef ref;
  final void Function(BuildContext context, CrmSearchHit hit) onOpen;

  @override
  State<_CrmDeepSearchBody> createState() => _CrmDeepSearchBodyState();
}

class _CrmDeepSearchBodyState extends State<_CrmDeepSearchBody> {
  Timer? _debounce;
  var _req = 0;
  List<CrmSearchHit> _hits = const [];
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch(widget.query);
  }

  @override
  void didUpdateWidget(_CrmDeepSearchBody oldWidget) {
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
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final myReq = ++_req;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final api = CrmDeepSearchApi(widget.ref.read(apiClientProvider));
        final hits = await api.search(q);
        if (!mounted || myReq != _req) return;
        setState(() {
          _hits = hits;
          _loading = false;
          _error = null;
        });
      } catch (e) {
        if (!mounted || myReq != _req) return;
        setState(() {
          _hits = const [];
          _loading = false;
          _error = extractApiError(e);
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
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_hits.isEmpty) {
      return const Center(child: Text('No CRM matches'));
    }
    return ListView.separated(
      itemCount: _hits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final hit = _hits[i];
        return ListTile(
          title: Text(
            hit.title.isNotEmpty ? hit.title : hit.contactName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (hit.contactName.isNotEmpty && hit.kind != 'contact')
                hit.contactName,
              if (hit.snippet.isNotEmpty) hit.snippet,
            ].join(' · '),
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
