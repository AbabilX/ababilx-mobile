import 'dart:async';

import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/calls/data/call_log_cache.dart';
import 'package:ababilx/features/calls/data/call_log_repository.dart';
import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:ababilx/features/calls/providers/call_log_merge.dart';
import 'package:ababilx/features/calls/providers/call_log_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CallLogEntry _call(String id, {int minute = 0}) => CallLogEntry(
  id: id,
  kind: 'direct',
  scope: 'personal',
  conversationId: 'conv',
  mode: 'audio',
  status: 'ended',
  direction: 'incoming',
  missed: false,
  title: 'Ada',
  startedAt: DateTime.utc(2026, 9, 30, 10, minute),
);

List<CallLogEntry> _calls(List<String> ids) => [for (final i in ids) _call(i)];

List<String> _ids(List<CallLogEntry> calls) => [for (final c in calls) c.id];

class _Repo implements CallLogRepository {
  _Repo(this.pages);
  final List<CallLogPage> pages;
  int requests = 0;
  Completer<void>? gate;

  @override
  Future<CallLogPage> page({String? before, int limit = 50}) async {
    requests++;
    await gate?.future;
    return pages[(requests - 1).clamp(0, pages.length - 1)];
  }
}

ProviderContainer _container(_Repo repo, {String owner = 'me'}) {
  final c = ProviderContainer(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(true),
      callLogRepositoryProvider.overrideWithValue(repo),
      callLogCacheProvider.overrideWithValue(CallLogCache(() async => owner)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('mergeFirstPage', () {
    test('keeps older pages below a page that reaches into them', () {
      final merged = mergeFirstPage(
        current: _calls(['c', 'b', 'a', 'z', 'y']),
        currentCursor: 'after-y',
        page: CallLogPage(calls: _calls(['d', 'c', 'b']), nextCursor: 'x'),
      );
      expect(_ids(merged.calls), ['d', 'c', 'b', 'a', 'z', 'y']);
      expect(merged.cursor, 'after-y');
    });

    test('a call deleted inside the page window is gone', () {
      final merged = mergeFirstPage(
        current: _calls(['c', 'b', 'a', 'z']),
        currentCursor: 'after-z',
        page: CallLogPage(calls: _calls(['c', 'a']), nextCursor: 'x'),
      );
      expect(_ids(merged.calls), ['c', 'a', 'z']);
    });

    test('no overlap replaces, cursor and all', () {
      final merged = mergeFirstPage(
        current: _calls(['b', 'a']),
        currentCursor: 'after-a',
        page: CallLogPage(calls: _calls(['e', 'd']), nextCursor: 'after-d'),
      );
      expect(_ids(merged.calls), ['e', 'd']);
      expect(merged.cursor, 'after-d');
    });
  });

  group('CallLogNotifier', () {
    test('draws the saved page before any request', () async {
      await CallLogCache(
        () async => 'me',
      ).write(CallLogPage(calls: _calls(['b', 'a']), nextCursor: 'k'));
      final repo = _Repo([
        CallLogPage(calls: _calls(['b', 'a']), nextCursor: ''),
      ]);
      final c = _container(repo);
      c.read(callLogProvider);
      await _settle();
      final s = c.read(callLogProvider);
      expect(_ids(s.calls), ['b', 'a']);
      expect(s.loaded, isTrue);
      expect(repo.requests, 0);
    });

    test("another account's saved page is never shown", () async {
      await CallLogCache(
        () async => 'someone-else',
      ).write(CallLogPage(calls: _calls(['x']), nextCursor: ''));
      final c = _container(
        _Repo([const CallLogPage(calls: [], nextCursor: '')]),
      );
      c.read(callLogProvider);
      await _settle();
      expect(c.read(callLogProvider).calls, isEmpty);
    });

    test('one request per launch, again only when marked stale', () async {
      final repo = _Repo([
        CallLogPage(calls: _calls(['a']), nextCursor: ''),
      ]);
      final c = _container(repo);
      final log = c.read(callLogProvider.notifier);
      await log.refreshIfStale();
      await log.refreshIfStale();
      await log.refreshIfStale();
      expect(repo.requests, 1);

      log.markStale();
      await log.refreshIfStale();
      expect(repo.requests, 2);
    });

    test('callers at the same moment share one request', () async {
      final repo = _Repo([
        CallLogPage(calls: _calls(['a']), nextCursor: ''),
      ])..gate = Completer<void>();
      final c = _container(repo);
      final log = c.read(callLogProvider.notifier);
      final all = [log.refreshIfStale(), log.load(silent: true), log.load()];
      repo.gate!.complete();
      await Future.wait(all);
      expect(repo.requests, 1);
    });

    test('a fetched page is saved for the next launch', () async {
      final repo = _Repo([
        CallLogPage(calls: _calls(['a']), nextCursor: 'k'),
      ]);
      await _container(repo).read(callLogProvider.notifier).load();
      await _settle();
      final saved = await CallLogCache(() async => 'me').read();
      expect(_ids(saved!.calls), ['a']);
      expect(saved.nextCursor, 'k');
    });

    test('a saved page round-trips every field', () async {
      final e = CallLogEntry.fromJson({
        ..._call('a').toJson(),
        'answered_at': '2026-09-30T10:00:05Z',
        'duration_sec': 42,
        'avatar_url': 'https://cdn/x.png',
      });
      final back = CallLogEntry.fromJson(e.toJson());
      expect(back.toJson(), e.toJson());
      expect(back.connected, isTrue);
    });
  });
}
