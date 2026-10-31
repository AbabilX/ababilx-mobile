import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/chat-pins/pinned_messages_screen.dart';
import 'package:ababilx/features/messages/chat-timeline/message_menu.dart';
import 'package:ababilx/features/messages/chat-timeline/message_menu_items.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _base = '/api/chat/conversations/chat-1/pinned-messages';

Map<String, dynamic> _message(String id, String body) => {
  'id': id,
  'conversation_id': 'chat-1',
  'user_id': 'user-1',
  'user_name': 'Alice',
  'body': body,
  'created_at': '2026-09-23T00:00:00Z',
};

class _Api extends ApiClient {
  _Api() : super(const SecureStorage(FlutterSecureStorage()));

  final pinned = <String, String>{
    'message-2': 'Newer pin',
    'message-1': 'Remember this',
  };
  bool failWrite = false;
  final writes = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    expect(path, _base);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'success': true,
                'data': {
                  'pins': [
                    for (final entry in pinned.entries)
                      {
                        'pinned_at': '2026-09-23T01:00:00Z',
                        'message': _message(entry.key, entry.value),
                      },
                  ],
                },
              }
              as T,
    );
  }

  Future<Response<T>> _write<T>(String path, String verb) async {
    expect(path, startsWith('$_base/'));
    writes.add('$verb ${path.substring(_base.length + 1)}');
    if (failWrite) throw StateError('offline');
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    final response = await _write<T>(path, 'PUT');
    pinned[path.split('/').last] = 'Pinned later';
    return response;
  }

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    final response = await _write<T>(path, 'DELETE');
    pinned.remove(path.split('/').last);
    return response;
  }
}

class _Chat extends ChatNotifier {
  @override
  ChatState build() => const ChatState(currentUserId: 'me');
}

void main() {
  test('pin API lists every pin and pins or unpins one message', () async {
    final api = _Api();
    final repo = ChatRepository(api);
    final pins = await repo.pinnedMessages('chat-1');
    expect(pins.map((p) => p.message.id), ['message-2', 'message-1']);
    expect(pins.first.pinnedAt, '2026-09-23T01:00:00Z');
    await repo.setMessagePinned('chat-1', 'message-3', pinned: true);
    await repo.setMessagePinned('chat-1', 'message-1', pinned: false);
    expect(api.writes, ['PUT message-3', 'DELETE message-1']);
    expect((await repo.pinnedMessages('chat-1')).map((p) => p.message.id), [
      'message-2',
      'message-3',
    ]);
  });

  test('long-press menu offers Pin or Unpin for a sent message', () {
    final labels = <String, String>{
      for (final name in [
        'reply',
        'forward',
        'save',
        'copy',
        'thread',
        'select',
        'edit',
        'pin',
        'unpin',
        'delete',
      ])
        name: name,
    };
    List<MessageMenuAction> actions(bool pinned, bool showPin) =>
        messageMenuItems(
          isMine: true,
          showThread: false,
          showSave: false,
          showSelect: true,
          showPin: showPin,
          pinned: pinned,
          labels: labels,
        ).map((item) => item.action).toList();
    expect(actions(false, true), contains(MessageMenuAction.pin));
    expect(actions(true, true), contains(MessageMenuAction.pin));
    expect(actions(false, false), isNot(contains(MessageMenuAction.pin)));
  });

  Future<_Api> mountPins(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _Api();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/pins'),
              child: const Text('open pins'),
            ),
          ),
        ),
        GoRoute(
          path: '/pins',
          builder: (_, _) =>
              const PinnedMessagesScreen(conversationId: 'chat-1'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          chatRepositoryProvider.overrideWithValue(ChatRepository(api)),
          chatProvider.overrideWith(_Chat.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('open pins'));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('pins screen draws the bubbles and unpins after server success', (
    tester,
  ) async {
    final api = await mountPins(tester)
      ..failWrite = true;
    expect(find.text('2 Pinned Messages'), findsOneWidget);
    expect(find.text('Remember this'), findsOneWidget);
    expect(find.text('Newer pin'), findsOneWidget);
    expect(find.byTooltip('Go to message'), findsNWidgets(2));

    Future<void> unpin() async {
      await tester.longPress(find.text('Remember this'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unpin message'));
      await tester.pumpAndSettle();
    }

    await unpin();
    expect(find.text('Remember this'), findsOneWidget);
    api.failWrite = false;
    await unpin();
    expect(find.text('Remember this'), findsNothing);
    expect(find.text('Newer pin'), findsOneWidget);
    expect(find.text('1 Pinned Message'), findsOneWidget);
    expect(api.writes, ['DELETE message-1', 'DELETE message-1']);
  });

  testWidgets('unpin all asks first, removes every pin and closes', (
    tester,
  ) async {
    final api = await mountPins(tester);
    await tester.tap(find.text('Unpin all'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin all 2 messages?'), findsOneWidget);
    await tester.tap(find.text('Unpin all messages').last);
    await tester.pumpAndSettle();
    expect(api.writes.toSet(), {'DELETE message-1', 'DELETE message-2'});
    expect(find.text('open pins'), findsOneWidget);
  });
}
