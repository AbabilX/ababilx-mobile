import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/chat-timeline/pinned_message_banner.dart';
import 'package:ababilx/features/messages/chat-timeline/signal_message_menu.dart';
import 'package:ababilx/features/messages/chat-timeline/signal_message_menu_items.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ApiClient {
  _Api() : super(const SecureStorage(FlutterSecureStorage()));

  String pinned = 'message-1';
  bool failWrite = false;
  final writes = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    expect(path, '/api/chat/conversations/chat-1/pinned-message');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'success': true,
                'data': {'message_id': pinned},
              }
              as T,
    );
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    expect(path, '/api/chat/conversations/chat-1/pinned-message');
    final id = (data as Map<String, dynamic>)['message_id'] as String;
    writes.add(id);
    if (failWrite) throw StateError('offline');
    pinned = id;
    return Response<T>(requestOptions: RequestOptions(path: path));
  }
}

void main() {
  test(
    'message pin API reads, replaces, and clears the personal pin',
    () async {
      final api = _Api();
      final repo = ChatRepository(api);
      expect(await repo.pinnedMessage('chat-1'), 'message-1');
      await repo.setPinnedMessage('chat-1', 'message-2');
      expect(await repo.pinnedMessage('chat-1'), 'message-2');
      await repo.setPinnedMessage('chat-1', null);
      expect(await repo.pinnedMessage('chat-1'), isNull);
      expect(api.writes, ['message-2', '']);
    },
  );

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
    List<SignalMessageAction> actions(bool pinned, bool showPin) =>
        signalMenuItems(
          isMine: true,
          showThread: false,
          showSave: false,
          showSelect: true,
          showPin: showPin,
          pinned: pinned,
          labels: labels,
        ).map((item) => item.action).toList();
    expect(actions(false, true), contains(SignalMessageAction.pin));
    expect(actions(true, true), contains(SignalMessageAction.pin));
    expect(actions(false, false), isNot(contains(SignalMessageAction.pin)));
  });

  testWidgets('pinned banner unpins only after server success', (tester) async {
    final api = _Api()..failWrite = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          chatRepositoryProvider.overrideWithValue(ChatRepository(api)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PinnedMessageBanner(
              conversationId: 'chat-1',
              messages: const [
                ChatMessage(
                  id: 'message-1',
                  conversationId: 'chat-1',
                  userId: 'user-1',
                  body: 'Remember this',
                  createdAt: '2026-09-23T00:00:00Z',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remember this'), findsOneWidget);
    await tester.tap(find.byTooltip('Unpin message'));
    await tester.pumpAndSettle();
    expect(find.text('Remember this'), findsOneWidget);
    api.failWrite = false;
    await tester.tap(find.byTooltip('Unpin message'));
    await tester.pumpAndSettle();
    expect(find.text('Remember this'), findsNothing);
    expect(api.writes, ['', '']);
  });
}
