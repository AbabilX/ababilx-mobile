import 'package:ababilx/features/messages/chat-select/message_selection.dart';
import 'package:ababilx/features/messages/chat-select/selection_menu_state.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  String id = 'm1',
  String userId = 'me',
  String body = 'hello',
  String createdAt = '2026-09-12T06:00:00Z',
  String? deletedAt,
  MessageSendStatus sendStatus = MessageSendStatus.sent,
  List<ChatMessageAttachment> attachments = const [],
  String? encryptedBody,
}) => ChatMessage(
  id: id,
  conversationId: 'c1',
  userId: userId,
  body: body,
  createdAt: createdAt,
  deletedAt: deletedAt,
  sendStatus: sendStatus,
  attachments: attachments,
  encryptedBody: encryptedBody,
  encryptionVersion: encryptedBody == null ? null : 1,
);

void main() {
  group('MessageSelection', () {
    late ProviderContainer container;
    MessageSelectionNotifier notifier() =>
        container.read(messageSelectionProvider.notifier);
    MessageSelection state() => container.read(messageSelectionProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('starts inactive and enters the mode with one message', () {
      expect(state().isActive, isFalse);
      notifier().start(conversationId: 'c1', messageId: 'm1');
      expect(state().isActiveIn('c1'), isTrue);
      expect(state().isActiveIn('c2'), isFalse);
    });

    test('unselecting the last message leaves the mode', () {
      notifier().start(conversationId: 'c1', messageId: 'm1');
      notifier().toggle(conversationId: 'c1', messageId: 'm2');
      expect(state().ids, {'m1', 'm2'});
      notifier().toggle(conversationId: 'c1', messageId: 'm2');
      notifier().toggle(conversationId: 'c1', messageId: 'm1');
      expect(state().isActive, isFalse);
    });

    test(
      'a different conversation replaces the selection, never adds to it',
      () {
        notifier().start(conversationId: 'c1', messageId: 'm1');
        notifier().toggle(conversationId: 'c2', messageId: 'm9');
        expect(state().conversationId, 'c2');
        expect(state().ids, {'m9'});
      },
    );

    test('retain drops ids the timeline no longer holds', () {
      notifier().start(conversationId: 'c1', messageId: 'm1');
      notifier().toggle(conversationId: 'c1', messageId: 'm2');
      notifier().retain({'m1'});
      expect(state().ids, {'m1'});
      notifier().retain(<String>{});
      expect(state().isActive, isFalse);
    });
  });

  group('selectionMenuState', () {
    test('one message offers the single-message actions', () {
      final menu = selectionMenuState(
        selected: [_message()],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.reply, isTrue);
      expect(menu.edit, isTrue);
      expect(menu.forward, isTrue);
      expect(menu.copy, isTrue);
      expect(menu.delete, isTrue);
      expect(menu.deleteForEveryone, isTrue);
    });

    test('two messages drop reply, edit and save — the selection rule', () {
      final menu = selectionMenuState(
        selected: [
          _message(id: 'm1'),
          _message(id: 'm2'),
        ],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.reply, isFalse);
      expect(menu.edit, isFalse);
      expect(menu.save, isFalse);
      expect(menu.forward, isTrue);
      expect(menu.copy, isTrue);
      expect(menu.delete, isTrue);
    });

    test('someone else\'s message is deleted for me only, never edited', () {
      final menu = selectionMenuState(
        selected: [_message(userId: 'them')],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.delete, isTrue);
      expect(menu.deleteForEveryone, isFalse);
      expect(menu.edit, isFalse);
      expect(menu.forward, isTrue);
      expect(menu.copy, isTrue);
    });

    test('a locked composer withholds reply and nothing else', () {
      final menu = selectionMenuState(
        selected: [_message()],
        currentUserId: 'me',
        canMessage: false,
      );
      expect(menu.reply, isFalse);
      expect(menu.forward, isTrue);
      expect(menu.copy, isTrue);
    });

    test('a message still sending is not forwardable or deletable', () {
      final menu = selectionMenuState(
        selected: [_message(sendStatus: MessageSendStatus.sending)],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.forward, isFalse);
      expect(menu.delete, isFalse);
      expect(menu.reply, isFalse);
    });

    test('a body this device never opened is neither forwarded nor copied', () {
      final menu = selectionMenuState(
        selected: [
          _message(body: 'Unable to decrypt this message', encryptedBody: 'x'),
        ],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.forward, isFalse);
      expect(menu.copy, isFalse);
    });

    test('forwarding stops at the 32-message cap', () {
      List<ChatMessage> batch(int n) => [
        for (var i = 0; i < n; i++) _message(id: 'm$i'),
      ];
      expect(
        selectionMenuState(
          selected: batch(maxForwardableMessages),
          currentUserId: 'me',
          canMessage: true,
        ).forward,
        isTrue,
      );
      expect(
        selectionMenuState(
          selected: batch(maxForwardableMessages + 1),
          currentUserId: 'me',
          canMessage: true,
        ).forward,
        isFalse,
      );
    });

    test('an attachment-only message still offers save and forward', () {
      final menu = selectionMenuState(
        selected: [
          _message(
            body: '',
            attachments: const [
              ChatMessageAttachment(
                id: 'a1',
                messageId: 'm1',
                fileName: 'photo.jpg',
                fileUrl: 'https://cdn.example/photo.jpg',
                contentType: 'image/jpeg',
                sizeBytes: 1024,
                uploadedBy: 'me',
                createdAt: '2026-09-12T06:00:00Z',
              ),
            ],
          ),
        ],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.save, isTrue);
      expect(menu.forward, isTrue);
      expect(menu.copy, isFalse);
    });
  });
}
