import 'dart:async';

import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/providers/chat_connections_provider.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/features/messages/screens/blocked_connections_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ApiClient {
  _Api() : super(const SecureStorage(FlutterSecureStorage()));
  bool blocked = true;
  bool failList = false;
  bool failDelete = false;
  final deletes = <String>[];
  Completer<void>? pending;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    expect(path, '/api/chat/connections/blocked');
    if (failList) throw StateError('offline');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'success': true,
                'data': {
                  'blocked': [
                    if (blocked)
                      {
                        'id': 'relationship-id',
                        'status': 'blocked',
                        'direction': 'outgoing',
                        'user': {
                          'user_id': 'peer-id',
                          'name': 'Ada',
                          'username': 'ada',
                        },
                      },
                  ],
                },
              }
              as T,
    );
  }

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    deletes.add(path);
    if (pending != null) await pending!.future;
    if (failDelete) throw StateError('offline');
    blocked = false;
    return Response<T>(requestOptions: RequestOptions(path: path));
  }
}

class _Chat extends ChatNotifier {
  int refreshes = 0;
  @override
  ChatState build() => const ChatState();
  @override
  Future<void> fetchSidebarSilent() async {
    refreshes++;
  }
}

class _Connections extends ChatConnectionsNotifier {
  int refreshes = 0;
  @override
  Future<void> refresh({bool force = false}) async {
    refreshes++;
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Api api,
    _Chat chat,
    _Connections connections,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWithValue('en'),
          chatRepositoryProvider.overrideWithValue(ChatRepository(api)),
          chatProvider.overrideWith(() => chat),
          chatConnectionsProvider.overrideWith(() => connections),
        ],
        child: const MaterialApp(home: BlockedConnectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unblock uses peer id, prevents double submit and refreshes both lists',
    (tester) async {
      final api = _Api()..pending = Completer<void>();
      final chat = _Chat();
      final connections = _Connections();
      await mount(tester, api, chat, connections);
      expect(find.text('Ada'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pump();
      await tester.tap(find.text('Unblock'));
      expect(api.deletes, ['/api/chat/connections/peer-id']);
      api.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ada'), findsNothing);
      expect(find.text('No blocked people'), findsOneWidget);
      expect(chat.refreshes, 1);
      expect(connections.refreshes, 1);
    },
  );

  testWidgets('failed unblock keeps person visible and allows retry', (
    tester,
  ) async {
    final api = _Api()..failDelete = true;
    final chat = _Chat();
    await mount(tester, api, chat, _Connections());
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(chat.refreshes, 0);
    api.failDelete = false;
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('blocked list failure can be retried', (tester) async {
    final api = _Api()..failList = true;
    await mount(tester, api, _Chat(), _Connections());
    expect(find.text('Tap to retry'), findsOneWidget);
    api.failList = false;
    await tester.tap(find.text('Tap to retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
  });
}
