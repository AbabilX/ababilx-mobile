import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../call-info/call_info_path.dart';
import '../data/models/call_log_entry.dart';
import 'call_log_cluster.dart';
import 'call_log_format.dart';
import 'call_log_row.dart';
import 'calls_list_chrome.dart';

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

/// First load, nothing to show yet.
class CallsLoading extends StatelessWidget {
  const CallsLoading({super.key, required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            AppTranslations.of(lang, 'calls_loading'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-screen [child] that still pulls to refresh. Every empty state needs
/// it — the failure copy says "pull to refresh", and AlwaysScrollable is what
/// gives a one-screen child something to drag.
class CallsRefreshableFill extends StatelessWidget {
  const CallsRefreshableFill({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: LayoutBuilder(
      builder: (context, box) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: box.maxHeight, child: child)],
      ),
    ),
  );
}

/// The history itself: date sections, one row per contact per day.
class CallsHistoryList extends StatelessWidget {
  const CallsHistoryList({
    super.key,
    required this.rows,
    required this.lang,
    required this.controller,
    required this.loadingMore,
    required this.callBusy,
    required this.onCall,
    required this.onLongPress,
  });

  final List<CallLogCluster> rows;
  final String lang;
  final ScrollController controller;
  final bool loadingMore;

  /// One live call at a time — redial goes inert while a call is up.
  final bool callBusy;
  final void Function(String conversationId, bool isGroup) onCall;
  final void Function(CallLogEntry entry) onLongPress;

  @override
  Widget build(BuildContext context) {
    final items = _items(rows, lang);
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.only(bottom: ShellPillMetrics.contentBottom(context)),
      itemCount: items.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = items[i];
        if (item is _CallSectionItem) {
          return CallSectionHeader(title: item.title);
        }
        final cluster = (item as _CallRowItem).cluster;
        final entry = cluster.lead;
        void call() => onCall(entry.conversationId, entry.isGroup);
        return Column(
          children: [
            CallLogRow(
              entry: entry,
              count: cluster.count,
              lang: lang,
              // That contact's calls on that day.
              onTap: () => context.push(
                entry.conversationId.isEmpty
                    ? '/messages/'
                    : callInfoPath(entry),
              ),
              // Group trailing is "open chat", not a redial — leave it
              // tappable while busy.
              onCall: entry.isGroup || !callBusy ? call : null,
              onLongPress: entry.isGroup || entry.conversationId.isEmpty
                  ? null
                  : () => onLongPress(entry),
            ),
            const Divider(height: 1, indent: 84),
          ],
        );
      },
    );
  }
}
