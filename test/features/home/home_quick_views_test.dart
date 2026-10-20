import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:ababilx/features/home/data/home_callers.dart';
import 'package:ababilx/features/home/header/home_header.dart';
import 'package:ababilx/features/home/quick-views/quick_view_prefs.dart';
import 'package:ababilx/features/home/quick-views/quick_views.dart';
import 'package:ababilx/features/messages/data/local/composer_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ComposerDraftStore.listAll', () {
    test(
      'lists one account\'s drafts, main and thread, nothing else',
      () async {
        final store = ComposerDraftStore();
        await store.write('me', 'conv-1', 'hello');
        await store.write('me', 'conv-1', 'in thread', parentId: 'root-1');
        await store.write('me', 'conv-2', '   ');
        await store.write('other', 'conv-3', 'not mine');
        // A send in flight leaves a `.send` binding beside the draft.
        await store.bindSend('me', 'conv-1', 'ref-1', 'hello');

        final drafts = await store.listAll('me');
        final seen = {
          for (final d in drafts) '${d.conversationId}/${d.parentId}': d.text,
        };
        expect(seen, {'conv-1/null': 'hello', 'conv-1/root-1': 'in thread'});
      },
    );

    test('no account, no drafts', () async {
      final store = ComposerDraftStore();
      await store.write('me', 'conv-1', 'hello');
      expect(await store.listAll(''), isEmpty);
    });
  });

  group('quick view order', () {
    test('default order is the enum order', () {
      expect(const QuickViewPrefs().arranged, HomeQuickView.values);
    });

    test('saved order wins; a view it never heard of goes last', () {
      // 'unread' was a card once; a stored name no build knows is ignored.
      expect(orderQuickViews(['groups', 'unread']), [
        HomeQuickView.groups,
        HomeQuickView.drafts,
        HomeQuickView.flock,
        HomeQuickView.localShare,
      ]);
    });

    test('every view has a card spec', () {
      for (final v in HomeQuickView.values) {
        expect(quickViewSpecs[v], isNotNull, reason: v.name);
      }
    });
  });

  group('frequent callers', () {
    CallLogEntry call(String conv, int minutesAgo, {String kind = 'dm'}) =>
        CallLogEntry.fromJson({
          'id': '$conv-$minutesAgo',
          'kind': kind,
          'conversation_id': conv,
          'title': conv,
          'started_at': DateTime.now()
              .subtract(Duration(minutes: minutesAgo))
              .toUtc()
              .toIso8601String(),
        });

    test('most calls first, one call is not a habit, groups left out', () {
      final got = frequentCallers([
        call('a', 1),
        call('b', 2),
        call('b', 3),
        call('b', 4),
        call('c', 5),
        call('c', 6),
        call('g', 7, kind: 'group'),
        call('g', 8, kind: 'group'),
      ]);
      expect([for (final c in got) c.latest.conversationId], ['b', 'c']);
      expect(got.first.count, 3);
      expect(got.first.latest.id, 'b-2');
    });
  });

  group('header', () {
    test('greeting follows the hour', () {
      expect(
        HomeHeader.greetingKey(DateTime(2026, 1, 1, 6)),
        'home_greet_morning',
      );
      expect(
        HomeHeader.greetingKey(DateTime(2026, 1, 1, 13)),
        'home_greet_afternoon',
      );
      expect(
        HomeHeader.greetingKey(DateTime(2026, 1, 1, 20)),
        'home_greet_evening',
      );
      expect(
        HomeHeader.greetingKey(DateTime(2026, 1, 1, 2)),
        'home_greet_evening',
      );
    });

    test('first name is the first word', () {
      expect(HomeHeader.firstName('  Murad  Hossain '), 'Murad');
      expect(HomeHeader.firstName(''), '');
    });
  });
}
