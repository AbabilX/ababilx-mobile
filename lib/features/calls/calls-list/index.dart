import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/providers/chat_provider.dart';
import '../providers/call_log_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_log_cluster.dart';
import 'call_log_row.dart';
import 'calls_empty.dart';

/// Call history tab. Bootstraps itself the way the chat screens do, so a cold
/// open straight onto /calls works with nothing else having run first.
class CallsList extends ConsumerStatefulWidget {
  const CallsList({super.key});

  @override
  ConsumerState<CallsList> createState() => _CallsListState();
}

class _CallsListState extends ConsumerState<CallsList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final log = ref.read(callLogProvider);
      ref.read(callLogProvider.notifier).load(silent: log.calls.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final left = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (left < 400) ref.read(callLogProvider.notifier).loadMore();
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

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(callLogProvider);
    final lang = ref.watch(appLanguageProvider);

    // Clustered over the whole accumulated list, not per page: a run split
    // across a page boundary merges by itself once the next page lands. This
    // rebuilds only when the log changes — ListView.builder scrolling does not
    // rebuild this widget.
    final rows = clusterCallLog(log.calls);

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.of(lang, 'calls_title'))),
      body: log.loading && log.calls.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
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
          : RefreshIndicator(
              onRefresh: () => ref.read(callLogProvider.notifier).load(),
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.only(
                  bottom: ShellPillMetrics.contentBottom(context),
                ),
                itemCount: rows.length + (log.loadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= rows.length) {
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
                  final cluster = rows[i];
                  final entry = cluster.lead;
                  return CallLogRow(
                    entry: entry,
                    count: cluster.count,
                    lang: lang,
                    onTap: () =>
                        context.push('/messages/${entry.conversationId}'),
                    onCall: () => _call(entry.conversationId, entry.isGroup),
                  );
                },
              ),
            ),
    );
  }
}
