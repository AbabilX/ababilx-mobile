import 'dart:async';
import 'dart:math';

import 'package:ababilx/core/network/ws_client.dart';
import 'package:ababilx/core/network/ws_link_up_provider.dart';
import 'package:ababilx/features/messages/chat-list/brand_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulated users of the reconnecting shimmer: flaky links on one phone each.
/// Seeded, so a failure repeats. Nothing here touches a server or a real
/// socket, so it says nothing about the server under reconnect load.
const _linkUsers = 10000;
const _screenUsers = 1000;

class _FakeWs extends Fake implements WsClient {
  _FakeWs({required this.connected});

  @override
  final bool connected;

  final up = StreamController<void>.broadcast(sync: true);
  final down = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get reconnects => up.stream;

  @override
  Stream<void> get disconnects => down.stream;
}

void main() {
  test(
    '$_linkUsers flaky links: state follows the socket, no listener left',
    () {
      final random = Random(20261031);
      var events = 0;
      for (var user = 0; user < _linkUsers; user++) {
        final ws = _FakeWs(connected: random.nextBool());
        final container = ProviderContainer(
          overrides: [wsClientProvider.overrideWithValue(ws)],
        );
        expect(container.read(wsLinkUpProvider), ws.connected);
        for (var n = random.nextInt(40); n > 0; n--) {
          final isUp = random.nextBool();
          (isUp ? ws.up : ws.down).add(null);
          events++;
          expect(container.read(wsLinkUpProvider), isUp, reason: 'user $user');
        }
        container.dispose();
        expect(ws.up.hasListener, isFalse, reason: 'user $user');
        expect(ws.down.hasListener, isFalse, reason: 'user $user');
      }
      // ignore: avoid_print
      print('LOAD shimmer links users=$_linkUsers events=$events');
    },
  );

  testWidgets(
    '$_screenUsers screens flapping: shimmer only while down, then still',
    (tester) async {
      final random = Random(7);
      final watch = Stopwatch()..start();
      var flips = 0;
      var masked = 0;
      for (var user = 0; user < _screenUsers; user++) {
        final ws = _FakeWs(connected: random.nextBool());
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(user),
            overrides: [wsClientProvider.overrideWithValue(ws)],
            child: const MaterialApp(
              home: Scaffold(body: ChatListBrandTitle()),
            ),
          ),
        );
        expect(
          find.byType(ShaderMask),
          ws.connected ? findsNothing : findsOneWidget,
          reason: 'user $user at mount',
        );
        var isUp = ws.connected;
        for (var n = random.nextInt(12); n > 0; n--) {
          isUp = random.nextBool();
          (isUp ? ws.up : ws.down).add(null);
          flips++;
          // Several flips can land inside one frame on a bad link.
          await tester.pump(Duration(milliseconds: random.nextInt(120)));
          expect(
            find.byType(ShaderMask),
            isUp ? findsNothing : findsOneWidget,
            reason: 'user $user flip $n',
          );
          if (!isUp) masked++;
          expect(find.text('AbabilX'), findsOneWidget);
        }
        // The link comes back and the title must stop asking for frames.
        if (!isUp) ws.up.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(ShaderMask), findsNothing, reason: 'user $user end');
        expect(tester.binding.hasScheduledFrame, isFalse, reason: 'user $user');
        expect(tester.takeException(), isNull, reason: 'user $user');
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print(
        'LOAD shimmer screens users=$_screenUsers flips=$flips '
        'shimmering=$masked ms=${watch.elapsedMilliseconds}',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
