import 'package:ababilx/features/calls/calls-list/call_log_row.dart';
import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:ababilx/shared/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('group call row renders the conversation image', (tester) async {
    final entry = CallLogEntry(
      id: 'call-1',
      kind: 'group',
      scope: 'personal',
      conversationId: 'conversation-1',
      mode: 'group',
      status: 'ended',
      direction: 'outgoing',
      missed: false,
      title: 'Design team',
      avatarUrl: 'https://example.test/group.png',
      startedAt: DateTime(2026, 9, 14),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallLogRow(entry: entry, onTap: () {}, onCall: () {}),
        ),
      ),
    );

    final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
    expect(avatar.url, 'https://example.test/group.png');
  });
}
