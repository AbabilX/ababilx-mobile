import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/call_log_seen_storage.dart';
import '../providers/call_log_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_log_cluster.dart';
import 'call_log_format.dart';
import 'call_log_row.dart';
import 'calls_empty.dart';

enum _CallFilter { all, missed }

sealed class _CallListItem {
  const _CallListItem();
}

class _CallSectionItem extends _CallListItem {
  const _CallSectionItem(this.title);
  final String title;
}

class _CallRowItem extends _CallListItem {
  const _CallRowItem(this.cluster);
  final CallLogCluster cluster;
}

/// Call history tab. Bootstraps itself the way the chat screens do, so a cold
/// open straight onto /calls works with nothing else having run first.
class CallsList extends ConsumerStatefulWidget {
  const CallsList({super.key});

  @override
  ConsumerState<CallsList> createState() => _CallsListState();
}

class _CallsListState extends ConsumerState<CallsList> {
  final _scroll = ScrollController();
  _CallFilter _filter = _CallFilter.all;
  DateTime? _lastSeenMissedAt;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final log = ref.read(callLogProvider);
      ref.read(callLogProvider.notifier).load(silent: log.calls.isNotEmpty);
    });
    lastSeenMissedCallAt().then((at) {
      if (mounted) setState(() => _lastSeenMissedAt = at);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    // Visiting the tab clears the badge for next time; this visit still
    // shows whatever count it opened with.
    markMissedCallsSeen(DateTime.now());
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final left = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (left < 400) ref.read(callLogProvider.notifier).loadMore();
  }

  /// Opening the Missed filter means those calls are seen — clear the badge
  /// now, not only when the tab is disposed.
  void _openMissedFilter() {
    final now = DateTime.now();
    setState(() {
      _filter = _CallFilter.missed;
      _lastSeenMissedAt = now;
    });
    markMissedCallsSeen(now);
  }

  /// Redial a 1:1 call when the conversation is still in the sidebar;
  /// otherwise just open it, which is also the only sane action for a group.
  void _call(String conversationId, bool isGroup) {
    final conversation = ref
        .read(chatProvider)
        .conversationById(conversationId);
    if (!isGroup && conversation != null && conversation.isDm) {
      ref.read(voiceCallProvider.notifier).startOutgoing(conversation);
      return;
    }
    context.push('/messages/$conversationId');
  }

  List<_CallListItem> _items(List<CallLogCluster> rows, String lang) {
    final items = <_CallListItem>[];
    String? lastSection;
    for (final cluster in rows) {
      final section = callDateHeading(cluster.lead.startedAt, lang: lang);
      if (section != lastSection) {
        items.add(_CallSectionItem(section));
        lastSection = section;
      }
      items.add(_CallRowItem(cluster));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(callLogProvider);
    final lang = ref.watch(appLanguageProvider);

    // Clustered over the whole accumulated list, not per page: a run split
    // across a page boundary merges by itself once the next page lands. This
    // rebuilds only when the log changes — ListView.builder scrolling does not
    // rebuild this widget.
    final allRows = clusterCallLog(log.calls);
    final rows = _filter == _CallFilter.missed
        ? allRows.where((row) => row.lead.missed).toList()
        : allRows;
    final items = _items(rows, lang);
    final unseenMissed = allRows.where((row) => row.lead.missed);
    final missedCount = _lastSeenMissedAt == null
        ? unseenMissed.length
        : unseenMissed
              .where((row) => row.lead.startedAt.isAfter(_lastSeenMissedAt!))
              .length;
    String t(String key) => AppTranslations.of(lang, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('calls_title')),
        actions: [
          _CallFilterAction(
            icon: Icons.call_rounded,
            label: t('calls_all'),
            selected: _filter == _CallFilter.all,
            onPressed: () => setState(() => _filter = _CallFilter.all),
          ),
          Badge(
            isLabelVisible: missedCount > 0,
            label: Text('$missedCount'),
            child: _CallFilterAction(
              icon: Icons.call_missed_rounded,
              label: t('calls_missed_filter'),
              selected: _filter == _CallFilter.missed,
              onPressed: _openMissedFilter,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: log.loading && log.calls.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2.5),
                  const SizedBox(height: 16),
                  Text(
                    t('calls_loading'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : log.calls.isEmpty
          // Both states pull to refresh — the failure copy says so, and it
          // was the one screen where it was not true: the empty branch sat
          // outside the RefreshIndicator, so the only way out of a failed
          // load was leaving the tab. AlwaysScrollable is what gives a
          // one-screen child something to drag.
          ? RefreshIndicator(
              onRefresh: () => ref.read(callLogProvider.notifier).load(),
              child: LayoutBuilder(
                builder: (context, box) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: box.maxHeight,
                      child: CallsEmpty(
                        error: log.error,
                        lang: lang,
                        // Calls start from a conversation, so the first-run
                        // button hands the user to the tab that has one.
                        // go(), not push(): Messages is a sibling shell tab.
                        onStart: () => context.go('/messages'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.read(callLogProvider.notifier).load(),
                    child: rows.isEmpty
                        ? LayoutBuilder(
                            builder: (context, box) => ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: box.maxHeight,
                                  child: CallsEmpty(
                                    missedOnly: true,
                                    lang: lang,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.only(
                              bottom: ShellPillMetrics.contentBottom(context),
                            ),
                            itemCount: items.length + (log.loadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i >= items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = items[i];
                              if (item is _CallSectionItem) {
                                return _CallSectionHeader(title: item.title);
                              }
                              final cluster = (item as _CallRowItem).cluster;
                              final entry = cluster.lead;
                              return Column(
                                children: [
                                  CallLogRow(
                                    entry: entry,
                                    count: cluster.count,
                                    lang: lang,
                                    onTap: () => context.push(
                                      '/messages/${entry.conversationId}',
                                    ),
                                    onCall: () => _call(
                                      entry.conversationId,
                                      entry.isGroup,
                                    ),
                                  ),
                                  const Divider(height: 1, indent: 84),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CallFilterAction extends StatelessWidget {
  const _CallFilterAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return IconButton.filledTonal(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon),
      );
    }
    return IconButton(onPressed: onPressed, tooltip: label, icon: Icon(icon));
  }
}

class _CallSectionHeader extends StatelessWidget {
  const _CallSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
