import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/chat-details/details_block_tile.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/blocked_connections_provider.dart';
import 'package:ababilx/features/messages/providers/chat_connections_provider.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chat extends ChatNotifier {
  @override
  ChatState build() => const ChatState();
  @override
  Future<void> fetchSidebarSilent() async {}
}

class _Connections extends ChatConnectionsNotifier {
  final calls = <String>[];
  @override
  Future<void> block(String userId) async => calls.add('block:$userId');
  @override
  Future<void> remove(String userId) async => calls.add('remove:$userId');
}

const _dm = ChatConversation(
  id: 'dm-1',
  teamId: '',
  scope: 'personal',
  type: 'dm',
  createdAt: '',
  peerUserId: 'peer-id',
  peerUserName: 'Ada',
  canMessage: false,
  lockReason: 'blocked',
);

const _openDm = ChatConversation(
  id: 'dm-1',
  teamId: '',
  scope: 'personal',
  type: 'dm',
  createdAt: '',
  peerUserId: 'peer-id',
  peerUserName: 'Ada',
  canMessage: true,
);

ChatConnection _blockedAda() => const ChatConnection(
  id: 'rel',
  user: ChatUserSummary(userId: 'peer-id', name: 'Ada'),
  status: 'blocked',
  direction: 'outgoing',
  createdAt: '',
);

void main() {
  Future<_Connections> mount(
    WidgetTester tester,
    List<ChatConnection> Function() blocked, {
    ChatConversation conversation = _dm,
  }) async {
    final connections = _Connections();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          chatProvider.overrideWith(_Chat.new),
          chatConnectionsProvider.overrideWith(() => connections),
          blockedConnectionsProvider.overrideWith((ref) async => blocked()),
        ],
        child: MaterialApp(
          home: Scaffold(body: DetailsBlockTile(conversation: conversation)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return connections;
  }

  testWidgets('a person I blocked offers Unblock, and it lifts my block', (
    tester,
  ) async {
    var list = [_blockedAda()];
    final connections = await mount(tester, () => list);
    expect(find.text('Unblock'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(find.text('Unblock Ada?'), findsOneWidget);
    list = [];
    await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
    await tester.pumpAndSettle();
    expect(connections.calls, ['remove:peer-id']);
    expect(find.text('Block'), findsOneWidget);
  });

  testWidgets('blocking stays on the screen and flips to Unblock', (
    tester,
  ) async {
    var list = <ChatConnection>[];
    final connections = await mount(tester, () => list, conversation: _openDm);
    expect(find.text('Block'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    list = [_blockedAda()];
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();
    expect(connections.calls, ['block:peer-id']);
    expect(find.text('Unblock'), findsOneWidget);
  });

  testWidgets('a block the peer placed never offers Unblock', (tester) async {
    await mount(tester, () => []);
    expect(find.text('Unblock'), findsNothing);
    expect(find.text('Block'), findsOneWidget);
  });
}
