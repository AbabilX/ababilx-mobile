import 'package:ababilx/features/messages/chat-select/selection_menu_state.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/shared/media/media_save_lock.dart';
import 'package:ababilx/shared/widgets/image_preview_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _photo = ChatMessageAttachment(
  id: 'a1',
  messageId: 'm1',
  fileName: 'photo.jpg',
  fileUrl: 'https://cdn.example/photo.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 1024,
  uploadedBy: 'me',
  createdAt: '2026-09-23T06:00:00Z',
);

const _mine = ChatMessage(
  id: 'm1',
  conversationId: 'g1',
  userId: 'me',
  body: 'hello',
  createdAt: '2026-09-23T06:00:00Z',
  attachments: [_photo],
);

/// A private group (server 0154) keeps its content inside it: no forward, no
/// save — the sender's own messages included — and viewers draw no Save or
/// Share while a private group's screen holds the lock.
void main() {
  tearDown(MediaSaveLock.resetForTest);

  group('selection menu', () {
    test('an open group still forwards and saves your own photo', () {
      final menu = selectionMenuState(
        selected: const [_mine],
        currentUserId: 'me',
        canMessage: true,
      );
      expect(menu.forward, isTrue);
      expect(menu.save, isTrue);
    });

    test('a private group drops forward and save, even for the sender', () {
      final menu = selectionMenuState(
        selected: const [_mine],
        currentUserId: 'me',
        canMessage: true,
        groupPrivacy: true,
      );
      expect(menu.forward, isFalse);
      expect(menu.save, isFalse);
      expect(menu.copy, isTrue, reason: 'copy stays');
      expect(menu.delete, isTrue);
    });
  });

  test('group_privacy survives the wire and the disk cache', () {
    final conv = ChatConversation.fromJson(const {
      'id': 'g1',
      'type': 'group',
      'scope': 'personal',
      'created_at': '',
      'group_privacy': true,
    });
    expect(conv.groupPrivacy, isTrue);
    expect(ChatConversation.fromJson(conv.toJson()).groupPrivacy, isTrue);
    expect(conv.copyWith(groupPrivacy: false).groupPrivacy, isFalse);
    expect(
      ChatConversation.fromJson(const {
        'id': 'g2',
        'created_at': '',
      }).groupPrivacy,
      isFalse,
    );
  });

  group('MediaSaveLock', () {
    Widget host({required bool outer, required bool inner}) => MaterialApp(
      home: MediaSaveLockScope(
        active: outer,
        child: MediaSaveLockScope(
          active: inner,
          child: const Scaffold(
            body: ImagePreviewDock(
              fileName: 'p.jpg',
              localPath: '/tmp/p.jpg',
              onRotate: _noop,
            ),
          ),
        ),
      ),
    );

    testWidgets('open: the dock offers Save and Share', (tester) async {
      await tester.pumpWidget(host(outer: false, inner: false));
      expect(find.byTooltip('Save'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
    });

    testWidgets('held: Save and Share go, Rotate stays', (tester) async {
      await tester.pumpWidget(host(outer: true, inner: false));
      expect(MediaSaveLock.held, isTrue);
      expect(find.byTooltip('Save'), findsNothing);
      expect(find.byTooltip('Share'), findsNothing);
      expect(find.text('Rotate'), findsOneWidget);
    });

    testWidgets('holds are counted and given back', (tester) async {
      await tester.pumpWidget(host(outer: true, inner: true));
      expect(MediaSaveLock.listenable.value, 2);
      // The inner screen closing must not unlock the outer one.
      await tester.pumpWidget(host(outer: true, inner: false));
      expect(MediaSaveLock.listenable.value, 1);
      await tester.pumpWidget(const SizedBox());
      expect(MediaSaveLock.held, isFalse);
      expect(MediaSaveLock.listenable.value, 0);
    });

    testWidgets('a dock with nothing left to offer draws nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaSaveLockScope(
            active: true,
            child: ImagePreviewDock(fileName: 'p.jpg', localPath: '/tmp/p'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(ImagePreviewDock),
          matching: find.byType(Material),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Save'), findsNothing);
    });
  });
}

void _noop() {}
