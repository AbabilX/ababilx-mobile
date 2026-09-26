import 'package:ababilx/features/calls/calls-list/call_log_cluster.dart';
import 'package:ababilx/features/calls/calls-list/call_log_format.dart';
import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 9, 12, 18);

CallLogEntry _call({
  String id = 'c',
  String conversation = 'conv1',
  String direction = 'incoming',
  bool missed = false,
  int minutesAgo = 0,
}) => CallLogEntry(
  id: id,
  kind: 'direct',
  scope: 'personal',
  conversationId: conversation,
  mode: 'audio',
  status: missed ? 'missed' : 'ended',
  direction: direction,
  missed: missed,
  title: 'Ada',
  startedAt: _base.subtract(Duration(minutes: minutesAgo)),
);

void main() {
  group('clusterCallLog', () {
    test('an empty log clusters to nothing', () {
      expect(clusterCallLog(const []), isEmpty);
    });

    test('calls to one person inside the window fold into one row', () {
      final rows = clusterCallLog([
        _call(id: 'a', minutesAgo: 0),
        _call(id: 'b', minutesAgo: 10),
        _call(id: 'c', minutesAgo: 25),
      ]);
      expect(rows, hasLength(1));
      expect(rows.single.count, 3);
      expect(rows.single.stacked, isTrue);
      // The newest call is what the row shows.
      expect(rows.single.lead.id, 'a');
    });

    test('a single call is a row of one and is not stacked', () {
      final rows = clusterCallLog([_call(id: 'a')]);
      expect(rows.single.count, 1);
      expect(rows.single.stacked, isFalse);
    });

    test('the window is measured against the lead, never the previous child', () {
      // Each call is 40 minutes after the one before it, so every neighbouring
      // pair is inside an hour — but the third is 80 minutes from the lead and
      // must start its own row, or a chain would drift indefinitely.
      final rows = clusterCallLog([
        _call(id: 'a', minutesAgo: 0),
        _call(id: 'b', minutesAgo: 40),
        _call(id: 'c', minutesAgo: 80),
      ]);
      expect(rows.map((r) => r.count), [2, 1]);
      expect(rows.last.lead.id, 'c');
    });

    test('a different person breaks the run', () {
      final rows = clusterCallLog([
        _call(id: 'a', conversation: 'conv1'),
        _call(id: 'b', conversation: 'conv2', minutesAgo: 5),
        _call(id: 'c', conversation: 'conv1', minutesAgo: 10),
      ]);
      expect(rows.map((r) => r.count), [1, 1, 1]);
    });

    test('direction breaks the run', () {
      final rows = clusterCallLog([
        _call(id: 'a', direction: 'incoming'),
        _call(id: 'b', direction: 'outgoing', minutesAgo: 5),
      ]);
      expect(rows, hasLength(2));
    });

    test('a missed call is never swallowed by an answered one', () {
      // The whole point of Signal's isEventMatch: a missed call is what
      // somebody is scanning this screen for.
      final rows = clusterCallLog([
        _call(id: 'a', missed: false),
        _call(id: 'b', missed: true, minutesAgo: 5),
        _call(id: 'c', missed: true, minutesAgo: 9),
      ]);
      expect(rows.map((r) => r.count), [1, 2]);
      expect(rows.last.lead.missed, isTrue);
    });

    test('an empty conversation id never joins anything', () {
      final rows = clusterCallLog([
        _call(id: 'a', conversation: ''),
        _call(id: 'b', conversation: '', minutesAgo: 2),
      ]);
      expect(rows, hasLength(2));
    });

    test('the window is configurable', () {
      final calls = [_call(id: 'a'), _call(id: 'b', minutesAgo: 90)];
      expect(clusterCallLog(calls).length, 2);
      expect(
        clusterCallLog(calls, window: const Duration(hours: 4)).single.count,
        2,
      );
    });
  });

  group('stackCallLogByContact (the call log default)', () {
    test('one contact on one day is one row, whatever the calls were', () {
      // Hours apart, both directions, missed and answered, another contact in
      // between: all of it is the same person that day.
      final rows = stackCallLogByContact([
        _call(id: 'a', minutesAgo: 0),
        _call(id: 'b', conversation: 'conv2', minutesAgo: 30),
        _call(id: 'c', direction: 'outgoing', minutesAgo: 120),
        _call(id: 'd', missed: true, minutesAgo: 300),
      ]);
      expect(rows.map((r) => r.lead.id), ['a', 'b']);
      expect(rows.map((r) => r.count), [3, 1]);
    });

    test('a new day starts a new row for the same contact', () {
      // _base is 18:00, so 19 hours back is the previous day.
      final rows = stackCallLogByContact([
        _call(id: 'a', minutesAgo: 0),
        _call(id: 'b', minutesAgo: 60),
        _call(id: 'c', minutesAgo: 19 * 60),
        _call(id: 'd', minutesAgo: 20 * 60),
      ]);
      expect(rows.map((r) => r.lead.id), ['a', 'c']);
      expect(rows.map((r) => r.count), [2, 2]);
    });

    test('calls with no conversation id stay apart', () {
      final rows = stackCallLogByContact([
        _call(id: 'a', conversation: ''),
        _call(id: 'b', conversation: '', minutesAgo: 2),
      ]);
      expect(rows, hasLength(2));
    });
  });

  group('formatting is localized', () {
    test('bn renders the subtitle in Bangla', () {
      final missed = _call(missed: true);
      expect(callSubtitle(missed, lang: 'en'), startsWith('Missed · '));
      expect(callSubtitle(missed, lang: 'bn'), startsWith('মিসড কল · '));
    });

    test('an unknown language falls back to English', () {
      expect(callDuration(0, lang: 'zz'), 'Answered');
    });

    test('duration digits are not translated', () {
      expect(callDuration(65, lang: 'bn'), '1:05');
    });
  });
}
