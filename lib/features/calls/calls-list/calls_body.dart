import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/call_log_entry.dart';
import '../providers/call_log_provider.dart';
import 'call_log_cluster.dart';
import 'calls_empty.dart';
import 'calls_history_view.dart';

/// What sits under the favourites: loading, an empty or failed history, a
/// filter or search with no match, or the history itself.
class CallsBody extends StatelessWidget {
  const CallsBody({
    super.key,
    required this.log,
    required this.rows,
    required this.lang,
    required this.searchQuery,
    required this.controller,
    required this.callBusy,
    required this.onRefresh,
    required this.onCall,
    required this.onLongPress,
  });

  final CallLogState log;
  final List<CallLogCluster> rows;
  final String lang;
  final String searchQuery;
  final ScrollController controller;
  final bool callBusy;
  final RefreshCallback onRefresh;
  final void Function(String conversationId, bool isGroup) onCall;
  final void Function(CallLogEntry entry) onLongPress;

  @override
  Widget build(BuildContext context) {
    if (log.loading && log.calls.isEmpty) return CallsLoading(lang: lang);
    if (log.calls.isEmpty) {
      return CallsRefreshableFill(
        onRefresh: onRefresh,
        child: CallsEmpty(
          error: log.error,
          lang: lang,
          // Calls start from a conversation, so the first-run button hands
          // the user to the tab that has one. go(), not push(): Messages is a
          // sibling shell tab.
          onStart: () => context.go('/messages'),
        ),
      );
    }
    if (rows.isEmpty) {
      return CallsRefreshableFill(
        onRefresh: onRefresh,
        child: CallsEmpty(
          missedOnly: true,
          searchQuery: searchQuery,
          lang: lang,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CallsHistoryList(
        rows: rows,
        lang: lang,
        controller: controller,
        loadingMore: log.loadingMore,
        callBusy: callBusy,
        onCall: onCall,
        onLongPress: onLongPress,
      ),
    );
  }
}
