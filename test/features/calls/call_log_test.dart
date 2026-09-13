import 'package:ababilx/features/calls/calls-list/call_log_format.dart';
import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  String kind = 'direct',
  String direction = 'incoming',
  bool missed = false,
  String? answeredAt,
  String? endedAt,
  int durationSec = 0,
}) => {
  'id': 'c1',
  'kind': kind,
  'scope': 'personal',
  'conversation_id': 'conv1',
  'team_id': '',
  'mode': kind == 'group' ? 'group' : 'audio',
  'status': missed ? 'missed' : 'ended',
  'direction': direction,
  'missed': missed,
  'peer_user_id': 'u2',
  'title': 'Ada',
  'started_at': '2026-08-24T10:00:00Z',
  'answered_at': answeredAt,
  'ended_at': endedAt,
  'duration_sec': durationSec,
};

void main() {
  group('CallLogEntry', () {
    test('parses a merged server row', () {
      final e = CallLogEntry.fromJson(
        _json(answeredAt: '2026-08-24T10:00:05Z', durationSec: 65),
      );
      expect(e.id, 'c1');
      expect(e.isGroup, isFalse);
      expect(e.isOutgoing, isFalse);
      expect(e.connected, isTrue);
      expect(e.durationSec, 65);
      // Timestamps arrive in UTC and are shown in local time.
      expect(e.startedAt.isUtc, isFalse);
    });

    test('missing optional fields never throw', () {
      final e = CallLogEntry.fromJson({'id': 'x'});
      expect(e.kind, 'direct');
      expect(e.title, isEmpty);
      expect(e.answeredAt, isNull);
      expect(e.connected, isFalse);
    });

    test('group rows carry the channel name and no peer', () {
      final e = CallLogEntry.fromJson(_json(kind: 'group'));
      expect(e.isGroup, isTrue);
      expect(e.mode, 'group');
    });

    test('a page keeps its cursor', () {
      final page = CallLogPage.fromJson({
        'calls': [_json(), _json()],
        'next_cursor': '2026-08-24T09:00:00Z',
      });
      expect(page.calls, hasLength(2));
      expect(page.nextCursor, '2026-08-24T09:00:00Z');
    });

    test('an empty page is a valid answer, not an error', () {
      final page = CallLogPage.fromJson({});
      expect(page.calls, isEmpty);
      expect(page.nextCursor, isEmpty);
    });
  });

  group('formatting', () {
    test('duration reads as clock time', () {
      expect(callDuration(0), 'Answered');
      expect(callDuration(65), '1:05');
      expect(callDuration(3725), '1:02:05');
    });

    test('missed beats duration in the subtitle', () {
      final e = CallLogEntry.fromJson(_json(missed: true));
      expect(callSubtitle(e), startsWith('Missed · '));
    });

    test('an unanswered outgoing call says so', () {
      final e = CallLogEntry.fromJson(_json(direction: 'outgoing'));
      expect(callSubtitle(e), startsWith('No answer · '));
    });

    test('direction icon distinguishes the three cases', () {
      final incoming = CallLogEntry.fromJson(_json());
      final outgoing = CallLogEntry.fromJson(_json(direction: 'outgoing'));
      final missed = CallLogEntry.fromJson(_json(missed: true));
      expect(callDirectionIcon(incoming), Icons.call_received_rounded);
      expect(callDirectionIcon(outgoing), Icons.call_made_rounded);
      expect(callDirectionIcon(missed), Icons.call_missed_rounded);
    });

    test('timestamp collapses by age', () {
      final now = DateTime.now();
      expect(
        callTimestamp(DateTime(now.year, now.month, now.day, 15, 4)),
        '15:04',
      );
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(hours: 3));
      expect(callTimestamp(yesterday), startsWith('Yesterday '));
      expect(callTimestamp(DateTime(2020, 5, 6, 8, 9)), '6/5/2020');
    });

    test('date headings separate today and yesterday', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final yesterday = today.subtract(const Duration(days: 1));
      expect(callDateHeading(today), 'Today');
      expect(callDateHeading(yesterday), 'Yesterday');
      expect(callDateHeading(today, lang: 'bn'), 'আজ');
    });
  });
}
