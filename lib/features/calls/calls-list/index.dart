import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../../core/router/swipe_tab_active.dart';
import '../data/call_log_seen_storage.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/call_log_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_log_cluster.dart';
import 'call_redial.dart';
import 'calls_app_bar.dart';
import 'calls_body.dart';
import 'calls_list_refresh.dart';
import 'calls_search.dart';
import '../favorites/call_favorite.dart';
import '../favorites/call_favorite_sheet.dart';
import '../../messages/chat-list/filter_reorder_blur.dart';
import '../favorites/call_favorites_strip.dart';

enum _CallFilter { all, missed }

/// Call history tab. Bootstraps itself the way the chat screens do, so a cold
/// open straight onto /calls works with nothing else having run first.
class CallsList extends ConsumerStatefulWidget {
  const CallsList({super.key});

  @override
  ConsumerState<CallsList> createState() => _CallsListState();
}

class _CallsListState extends ConsumerState<CallsList>
    with SwipeTabVisits, CallsListRefresh {
  final _scroll = ScrollController();
  _CallFilter _filter = _CallFilter.all;
  DateTime? _lastSeenMissedAt;
  bool _searching = false;
  String _query = '';

  /// Pages fetched for the current query, capped by [callSearchPageCap].
  int _searchPages = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    startCallLogRefresh();
    _openVisit();
  }

  /// The floating nav pill is painted over this page, so while the search
  /// field has the keyboard it would ride on top of it. Hidden for exactly as
  /// long as a search is open; the write is deferred because this is reached
  /// from didChangeDependencies and dispose, where a provider write throws.
  void _setSearching(bool value) {
    _searching = value;
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    Future.microtask(() => hidden.state = value);
  }

  /// Every visit, not once: the Chats/Talks pager keeps this tab alive.
  void _openVisit() {
    refreshCallLogOnVisit();
    lastSeenMissedCallAt().then((at) {
      if (mounted) setState(() => _lastSeenMissedAt = at);
    });
  }

  @override
  void onTabShown() => _openVisit();

  /// Leaving clears the badge for next time, and closes a search whose
  /// PopScope would otherwise swallow Back on Chats.
  @override
  void onTabHidden() {
    markMissedCallsSeen(DateTime.now());
    if (_searching) _setSearching(false);
    _query = '';
    _searchPages = 0;
  }

  @override
  void dispose() {
    stopCallLogRefresh();
    _scroll.dispose();
    if (_searching) _setSearching(false);
    if (tabActive) markMissedCallsSeen(DateTime.now());
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

  void _closeSearch() => setState(() {
    _setSearching(false);
    _query = '';
  });

  /// A search reaches past the loaded pages: while it has too few rows to
  /// scroll (so the scroll listener never fires), fetch the next page.
  void _pageForSearch(CallLogState log) {
    if (_query.trim().isEmpty ||
        !log.hasMore ||
        log.loading ||
        log.loadingMore ||
        _searchPages >= callSearchPageCap) {
      return;
    }
    _searchPages++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(callLogProvider.notifier).loadMore();
    });
  }

  void _call(String conversationId, bool isGroup) =>
      redialCall(context, ref, conversationId, isGroup: isGroup);

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(callLogProvider);
    final lang = ref.watch(appLanguageProvider);
    // Same gate as ChatHeader: one live call at a time — redial icons go
    // inert while a DM or group call is up (including minimized).
    final callBusy =
        ref.watch(voiceCallProvider.select((s) => s.active)) ||
        ref.watch(groupCallProvider.select((s) => s.active));
    watchCallsEnding();

    // Clustered over the whole accumulated list, not per page: a run split
    // across a page boundary merges by itself once the next page lands. This
    // rebuilds only when the log changes — ListView.builder scrolling does not
    // rebuild this widget.
    final allRows = clusterCallLog(log.calls);
    // One row per contact per day; the date sections keep days apart and the
    // row opens that day's calls (WhatsApp's Call info).
    final rows = stackCallLogByContact(
      searchCallLog(
        _filter == _CallFilter.missed
            ? log.calls.where((c) => c.missed).toList()
            : log.calls,
        _query,
      ),
    );
    _pageForSearch(log);
    final missedCount = unseenMissedCount(allRows, _lastSeenMissedAt);
    String t(String key) => AppTranslations.of(lang, key);
    Future<void> refresh() => ref.read(callLogProvider.notifier).load();

    final page = Scaffold(
      appBar: CallsAppBar(
        t: t,
        searching: _searching,
        missedOnly: _filter == _CallFilter.missed,
        missedCount: missedCount,
        onSearch: () => setState(() => _setSearching(true)),
        onCloseSearch: _closeSearch,
        onQuery: (value) => setState(() {
          _query = value;
          _searchPages = 0;
        }),
        onAll: () => setState(() => _filter = _CallFilter.all),
        onMissed: _openMissedFilter,
      ),
      // Favourites stay up whatever the history is doing (loading, empty,
      // failed) — they are on the phone. A search hides them.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_searching) const CallFavoritesStrip(),
          Expanded(
            child: FilterReorderBlur(
              child: CallsBody(
                log: log,
                rows: rows,
                lang: lang,
                searchQuery: _query.trim(),
                controller: _scroll,
                callBusy: callBusy,
                onRefresh: refresh,
                onCall: _call,
                onLongPress: (entry) => showCallFavoriteSheet(
                  context,
                  ref,
                  CallFavorite.fromEntry(entry),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // Back closes the search before it leaves the tab.
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: page,
    );
  }
}
