import 'dart:async';

import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/presence/online_presence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds socket frames by hand; never opens a real connection.
class FakeWs extends WsClient {
  FakeWs() : super(const SecureStorage(FlutterSecureStorage()));
  final frames = StreamController<Map<String, dynamic>>.broadcast();
  final drops = StreamController<void>.broadcast();
  @override
  Stream<Map<String, dynamic>> get events => frames.stream;
  @override
  Stream<void> get disconnects => drops.stream;
  @override
  Future<void> connect() async {}
}

void main() {
  late FakeWs ws;
  late ProviderContainer c;

  setUp(() async {
    ws = FakeWs();
    c = ProviderContainer(overrides: [wsClientProvider.overrideWithValue(ws)]);
    await c.read(onlinePresenceProvider.notifier).bootstrap();
  });
  tearDown(() => c.dispose());

  Future<void> send(Map<String, dynamic> frame) async {
    ws.frames.add(frame);
    await Future<void>.delayed(Duration.zero);
  }

  test('snapshot marks the roster online', () async {
    await send({
      'type': 'attendance.presence.snapshot',
      'online_user_ids': ['a', 'b'],
    });
    expect(c.read(isUserOnlineProvider('a')), isTrue);
    expect(c.read(isUserOnlineProvider('b')), isTrue);
    expect(c.read(isUserOnlineProvider('z')), isFalse);
  });

  test('edges add and remove one person', () async {
    await send({
      'type': 'attendance.presence',
      'presence': {'user_id': 'a', 'online': true},
    });
    expect(c.read(isUserOnlineProvider('a')), isTrue);
    await send({
      'type': 'attendance.presence',
      'presence': {'user_id': 'a', 'online': false},
    });
    expect(c.read(isUserOnlineProvider('a')), isFalse);
  });

  test('our own socket dropping clears everyone', () async {
    await send({
      'type': 'attendance.presence.snapshot',
      'online_user_ids': ['a'],
    });
    ws.drops.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(isUserOnlineProvider('a')), isFalse);
  });
}
