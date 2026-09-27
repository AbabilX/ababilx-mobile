import 'package:ababilx/features/messages/history-restore/history_restore_banner.dart';
import 'package:ababilx/features/messages/history-restore/history_restore_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String tr(String key) => switch (key) {
    'history_restore_messages' => 'Restoring messages… {done} / {total}',
    'history_restore_messages_running' => 'Restoring messages… {done}',
    _ => 'Restoring messages…',
  };
  HistoryRestoreState running({int messages = 0, int? total}) =>
      HistoryRestoreState(
        phase: HistoryRestorePhase.running,
        done: 3,
        total: 21,
        messages: messages,
        messageTotal: total,
      );

  test('counts messages against the server total, never chats', () {
    expect(
      historyRestoreLabel(tr, running(messages: 1234, total: 5678)),
      'Restoring messages… 1,234 / 5,678',
    );
  });
  test('no total yet (or an old server): the running count alone', () {
    expect(
      historyRestoreLabel(tr, running(messages: 40)),
      'Restoring messages… 40',
    );
    expect(historyRestoreLabel(tr, running()), 'Restoring messages…');
  });
  test('a message arriving mid-restore never reads past the total', () {
    expect(
      historyRestoreLabel(tr, running(messages: 11, total: 10)),
      'Restoring messages… 11 / 11',
    );
  });
  test('progress counts add up and stop once finished', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(historyRestoreProvider.notifier);
    notifier.begin(2);
    notifier.setMessageTotal(150);
    notifier.addMessages(100);
    notifier.addMessages(50);
    expect(container.read(historyRestoreProvider).messages, 150);
    expect(container.read(historyRestoreProvider).messageTotal, 150);
    notifier.finish();
    notifier.addMessages(5);
    expect(container.read(historyRestoreProvider).messages, 0);
  });
}
