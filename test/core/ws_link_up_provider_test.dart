import 'dart:async';

import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/core/network/ws_link_up_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWs extends Fake implements WsClient {
  _FakeWs({required this.connected});

  @override
  final bool connected;

  final up = StreamController<void>.broadcast();
  final down = StreamController<void>.broadcast();

  @override
  Stream<void> get reconnects => up.stream;

  @override
  Stream<void> get disconnects => down.stream;
}

ProviderContainer _containerFor(_FakeWs ws) {
  final container = ProviderContainer(
    overrides: [wsClientProvider.overrideWithValue(ws)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('a socket another feature already opened reads as up', () {
    // Presence and calls connect first; their "connected" event is long gone.
    final container = _containerFor(_FakeWs(connected: true));
    expect(container.read(wsLinkUpProvider), isTrue);
  });

  test('no socket yet reads as down', () {
    final container = _containerFor(_FakeWs(connected: false));
    expect(container.read(wsLinkUpProvider), isFalse);
  });

  test('follows the socket down and back up', () async {
    final ws = _FakeWs(connected: true);
    final container = _containerFor(ws);
    container.read(wsLinkUpProvider);

    ws.down.add(null);
    await _settle();
    expect(container.read(wsLinkUpProvider), isFalse);

    ws.up.add(null);
    await _settle();
    expect(container.read(wsLinkUpProvider), isTrue);
  });

  test('stops listening when disposed', () async {
    final ws = _FakeWs(connected: true);
    final container = ProviderContainer(
      overrides: [wsClientProvider.overrideWithValue(ws)],
    );
    container.read(wsLinkUpProvider);
    expect(ws.down.hasListener, isTrue);
    container.dispose();
    expect(ws.down.hasListener, isFalse);
    expect(ws.up.hasListener, isFalse);
  });
}
