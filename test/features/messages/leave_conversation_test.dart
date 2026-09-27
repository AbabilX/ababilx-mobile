import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Notifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(currentUserId: 'me');
}

/// Leaving a chat used to leave it "active" (copyWith could not null the id),
/// so its next message was acknowledged as read to the sender while nobody
/// was looking. ConversationScreen now calls leaveConversation after the frame.
void main() {
  late ProviderContainer container;
  late ChatNotifier chat;
  const a = '11111111-1111-4111-8111-111111111111';
  const b = '22222222-2222-4222-8222-222222222222';

  setUp(() {
    container = ProviderContainer(
      overrides: [chatProvider.overrideWith(_Notifier.new)],
    );
    chat = container.read(chatProvider.notifier);
  });
  tearDown(() => container.dispose());

  String? active() => container.read(chatProvider).activeConversationId;

  test('leaving the only chat clears "active"', () {
    chat.setActiveConversation(a);
    chat.leaveConversation(a);
    expect(active(), isNull);
  });

  test('setActiveConversation(null) really clears now', () {
    chat.setActiveConversation(a);
    chat.setActiveConversation(null);
    expect(active(), isNull);
  });

  test('closing a chat opened over another hands "active" back', () {
    chat.setActiveConversation(b);
    chat.leaveConversation(b, next: a);
    expect(active(), a);
  });

  test('a late leave never undoes the next screen', () {
    chat.setActiveConversation(a);
    chat.setActiveConversation(b); // the new screen claimed it first
    chat.leaveConversation(a);
    expect(active(), b);
  });

  test('closing a thread keeps its conversation active', () {
    chat.setActiveConversation(a);
    chat.setThreadRootId('root');
    chat.leaveConversation(a, threadRootId: 'root', next: a);
    expect(active(), a);
    expect(container.read(chatProvider).threadRootId, isNull);
  });
}
