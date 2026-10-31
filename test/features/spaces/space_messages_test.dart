import 'package:ababilx/features/spaces/data/space_api.dart';
import 'package:ababilx/features/spaces/data/space_invite.dart';
import 'package:ababilx/features/spaces/data/space_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_adapter.dart';

void main() {
  group('parseInviteCode', () {
    test('accepts the link, a bare code, and trims', () {
      expect(parseInviteCode('https://www.ababilx.com/s/Ab3dEf9'), 'Ab3dEf9');
      expect(parseInviteCode('  www.ababilx.com/s/Ab3dEf9/  '), 'Ab3dEf9');
      expect(parseInviteCode('ababilx.com/s/Ab3dEf9?x=1'), 'Ab3dEf9');
      expect(parseInviteCode('Ab3dEf9'), 'Ab3dEf9');
    });
    test('refuses other sites and junk', () {
      expect(parseInviteCode('https://evil.com/s/Ab3dEf9'), isNull);
      expect(parseInviteCode('https://www.ababilx.com/u/someone'), isNull);
      expect(parseInviteCode(''), isNull);
      expect(parseInviteCode('a b'), isNull);
      expect(parseInviteCode('../../etc'), isNull);
      expect(parseInviteCode('x' * 65), isNull);
    });
  });

  test('messages parse tolerant, newest first kept as sent', () {
    final list = SpaceMessage.listFromJson({
      'messages': [
        {
          'id': 'm1',
          'body': 'hi',
          'created_at': '2026-10-31T10:00:00Z',
          'author': {'id': 'u1', 'name': 'Murad', 'avatar_url': ''},
        },
        {'id': '', 'body': 'bad'},
        {'id': 'm2', 'body': 'no author', 'created_at': 'not a date'},
      ],
    });
    expect(list.map((m) => m.id), ['m1', 'm2']);
    expect(list.first.authorName, 'Murad');
    expect(list.last.authorName, isEmpty);
    expect(list.last.createdAt, isNull);
  });

  group('SpaceApi writes', () {
    late FakeAdapter adapter;
    late SpaceApi api;
    setUp(() {
      adapter = FakeAdapter((_) => (200, ok({})));
      final dio = Dio(BaseOptions(baseUrl: 'https://space.test'))
        ..httpClientAdapter = adapter;
      api = SpaceApi(dio: dio);
    });

    test('create posts the trimmed name', () async {
      adapter.handler = (_) => (
        200,
        ok({
          'space': {'id': 's9', 'name': 'Hex'},
        }),
      );
      final s = await api.createSpace('  Hex  ');
      expect(s.id, 's9');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/spaces');
      expect(adapter.requests.single.data, {'name': 'Hex'});
    });

    test('join posts the code', () async {
      adapter.handler = (_) => (
        200,
        ok({
          'space': {'id': 's1', 'name': 'A'},
        }),
      );
      await api.joinInvite('Ab3dEf9');
      expect(adapter.requests.single.uri.path, '/api/spaces/join');
      expect(adapter.requests.single.data, {'code': 'Ab3dEf9'});
    });

    test('a write answer without a space is a failure', () async {
      adapter.handler = (_) => (200, ok({}));
      await expectLater(api.createSpace('x'), throwsA(anything));
    });

    test('send carries a client id for safe retry', () async {
      adapter.handler = (_) => (
        200,
        ok({
          'message': {'id': 'm1', 'body': 'yo'},
        }),
      );
      final m = await api.send('s1', 'c1', 'yo', clientId: 'cid-1');
      expect(m.id, 'm1');
      expect(
        adapter.requests.single.path,
        '/api/spaces/s1/channels/c1/messages',
      );
      expect(adapter.requests.single.data, {
        'body': 'yo',
        'client_id': 'cid-1',
      });
    });

    test('messages GET with before cursor', () async {
      adapter.handler = (_) => (200, ok({'messages': []}));
      await api.messages('s1', 'c1', before: 'm5');
      expect(adapter.requests.single.uri.query, 'before=m5');
    });
  });
}
