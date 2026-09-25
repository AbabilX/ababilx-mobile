import 'package:ababilx/features/chat-lock/providers/chat_lock_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openFolderWith unlocks only the revealed chats', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(chatLockSessionProvider.notifier);

    session.openFolderWith(['a', 'c']);

    final open = container.read(chatLockSessionProvider);
    expect(open.folderOpen, isTrue);
    expect(open.folderVisible, {'a', 'c'});
    expect(open.unlocked, {'a', 'c'});
    expect(open.isOpen('a'), isTrue);
    expect(open.isOpen('b'), isFalse);
  });

  test('leaving a chat keeps it on the folder list', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(chatLockSessionProvider.notifier);

    session.openFolderWith(['a', 'b']);
    session.relock('a');

    final state = container.read(chatLockSessionProvider);
    expect(state.folderVisible, {'a', 'b'});
    expect(state.unlocked, {'b'});
    expect(state.folderOpen, isTrue);
  });

  test('closeFolder clears the reveal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(chatLockSessionProvider.notifier);

    session.openFolderWith(['a']);
    session.closeFolder();

    final state = container.read(chatLockSessionProvider);
    expect(state.folderOpen, isFalse);
    expect(state.folderVisible, isEmpty);
    expect(state.unlocked, isEmpty);
  });
}
