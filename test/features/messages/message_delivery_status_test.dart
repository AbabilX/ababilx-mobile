import 'package:ababilx/features/messages/chat-timeline/message_delivery_status.dart';
import 'package:ababilx/features/messages/chat-timeline/message_seen.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ink = Color(0xFF777777);

ChatDeliverySummary _summary({int delivered = 0, int read = 0}) =>
    ChatDeliverySummary(
      targetedDevices: 1,
      deliveredDevices: delivered,
      readDevices: read,
    );

Future<Icon> _pump(
  WidgetTester tester, {
  ChatDeliverySummary? delivery,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MessageDeliveryStatus(
        status: MessageSendStatus.sent,
        pulse: const AlwaysStoppedAnimation(1),
        delivery: delivery,
        color: _ink,
      ),
    ),
  );
  return tester.widget<Icon>(find.byType(Icon));
}

void main() {
  seenRules();

  testWidgets('sent is one tick in the bubble ink', (tester) async {
    final icon = await _pump(tester);
    expect(icon.icon, Icons.done_rounded);
    expect(icon.color, _ink);
  });

  testWidgets('delivered is a double tick in the bubble ink', (tester) async {
    final icon = await _pump(tester, delivery: _summary(delivered: 1));
    expect(icon.icon, Icons.done_all_rounded);
    expect(icon.color, _ink);
  });

  testWidgets('seen is a green double tick in light theme', (tester) async {
    final icon = await _pump(tester, delivery: _summary(delivered: 1, read: 1));
    expect(icon.icon, Icons.done_all_rounded);
    expect(icon.color, const Color(0xFF16A34A));
  });

  testWidgets('seen is a green double tick in dark theme', (tester) async {
    final icon = await _pump(
      tester,
      delivery: _summary(read: 1),
      brightness: Brightness.dark,
    );
    expect(icon.icon, Icons.done_all_rounded);
    expect(icon.color, const Color(0xFF22C55E));
  });
}

void seenRules() {
  test('older than the read time is seen, the same instant is not', () {
    expect(
      seenByReadTime('2026-10-31T10:00:00Z', '2026-10-31T10:00:01Z'),
      isTrue,
    );
    expect(
      seenByReadTime('2026-10-31T10:00:01Z', '2026-10-31T10:00:01Z'),
      isFalse,
    );
    expect(
      seenByReadTime('2026-10-31T10:00:02Z', '2026-10-31T10:00:01Z'),
      isFalse,
    );
    expect(seenByReadTime('2026-10-31T10:00:00Z', null), isFalse);
    expect(seenByReadTime('junk', '2026-10-31T10:00:01Z'), isFalse);
  });

  test('offsets compare as instants', () {
    expect(
      seenByReadTime('2026-10-31T16:00:00+06:00', '2026-10-31T10:00:01Z'),
      isTrue,
    );
  });

  test('a late event never moves the read time back', () {
    const newer = '2026-10-31T10:00:02Z';
    const older = '2026-10-31T10:00:01Z';
    expect(laterReadTime(newer, older), newer);
    expect(laterReadTime(older, newer), newer);
    expect(laterReadTime(null, older), older);
  });

  test('the read time survives the sidebar cache round trip', () {
    final row = ChatConversation.fromJson({
      'id': 'c1',
      'type': 'dm',
      'others_read_at': '2026-10-31T10:00:02Z',
    });
    expect(row.othersReadAt, '2026-10-31T10:00:02Z');
    expect(
      ChatConversation.fromJson(row.toJson()).othersReadAt,
      row.othersReadAt,
    );
  });

  testWidgets('a purged message with no receipts is green once seen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessageDeliveryStatus(
          status: MessageSendStatus.sent,
          pulse: AlwaysStoppedAnimation(1),
          color: _ink,
          seen: true,
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.done_all_rounded);
    expect(icon.color, const Color(0xFF16A34A));
  });
}
