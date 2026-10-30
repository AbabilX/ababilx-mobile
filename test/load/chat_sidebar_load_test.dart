import 'dart:io';

import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/features/messages/providers/chat_sidebar_slice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1000 simulated peers talking at once, against the real
/// `chatSidebarProvider`. Off by default: `LOAD=1 flutter test test/load`.
///
/// Counts how often a conversation list would be told to rebuild, and whether
/// the row it ends up with is right.
const _peers = 1000;
const _timelineEvents = 50000;
const _sidebarEvents = 1000;

class _Chat extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    dms: [for (var i = 0; i < _peers; i++) _dm(i, 0)],
  );

  void push(ChatState next) => state = next;
}

ChatConversation _dm(int peer, int unread) => ChatConversation.fromJson({
  'id': 'dm-$peer',
  'type': 'dm',
  'name': 'peer $peer',
  'unread_count': unread,
});

void main() {
  final enabled = Platform.environment['LOAD'] == '1';

  test('1000 peers: only sidebar changes reach a conversation list', () {
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(_Chat.new)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier) as _Chat;

    var whole = 0;
    var slice = 0;
    final subs = [
      container.listen(chatProvider, (_, _) => whole++),
      container.listen(chatSidebarProvider, (_, _) => slice++),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });

    final clock = Stopwatch()..start();
    for (var i = 0; i < _timelineEvents; i++) {
      final current = container.read(chatProvider);
      final peer = i % _peers;
      notifier.push(
        current.copyWith(
          feeds: {...current.feeds, 'dm-$peer': const ChatFeed()},
          sending: i.isEven,
          wsConnected: true,
        ),
      );
      if (i % (_timelineEvents ~/ _sidebarEvents) == 0) {
        final dms = [...current.dms];
        dms[peer] = _dm(peer, i);
        notifier.push(container.read(chatProvider).copyWith(dms: dms));
      }
      container.read(chatSidebarProvider);
    }
    final ms = clock.elapsedMilliseconds;

    // ignore: avoid_print
    print(
      '[load] peers=$_peers events=${_timelineEvents + _sidebarEvents} '
      'wholeStateListeners=$whole sliceListeners=$slice '
      'feeds=${container.read(chatProvider).feeds.length} time=${ms}ms',
    );
    expect(slice, _sidebarEvents);
    expect(whole, _timelineEvents + _sidebarEvents);

    // The list ends up with the newest row, not a stale one.
    final last = _timelineEvents - _timelineEvents ~/ _sidebarEvents;
    final row = container
        .read(chatSidebarProvider)
        .dms[last % _peers];
    expect(row.id, 'dm-${last % _peers}');
    expect(row.unreadCount, last);
  }, skip: enabled ? false : 'set LOAD=1');
}
