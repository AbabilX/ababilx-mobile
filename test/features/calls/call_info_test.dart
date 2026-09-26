import 'package:ababilx/features/calls/call-info/call_info_format.dart';
import 'package:ababilx/features/calls/call-info/call_info_path.dart';
import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

CallLogEntry _call(
  String id, {
  String conversation = 'conv1',
  required DateTime at,
  bool missed = false,
  String direction = 'incoming',
  int duration = 0,
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
  startedAt: at,
  answeredAt: duration > 0 ? at : null,
  durationSec: duration,
);

void main() {
  test('the path round-trips the stacked row\'s day', () {
    final entry = _call('a', at: DateTime(2026, 9, 24, 18, 41));
    final path = callInfoPath(entry);
    expect(path, '/call-info/conv1?day=2026-9-24');
    expect(
      parseCallInfoDay(Uri.parse(path).queryParameters['day']),
      DateTime(2026, 9, 24),
    );
  });

  test('a malformed day falls back to today, never throws', () {
    final now = DateTime.now();
    expect(parseCallInfoDay('x-y'), DateTime(now.year, now.month, now.day));
    expect(parseCallInfoDay(null), DateTime(now.year, now.month, now.day));
  });

  test('that contact on that day only, oldest first', () {
    // The log arrives newest first.
    final log = [
      _call('d', at: DateTime(2026, 9, 25, 9)),
      _call('c', at: DateTime(2026, 9, 24, 19, 10)),
      _call('x', conversation: 'conv2', at: DateTime(2026, 9, 24, 19)),
      _call('b', at: DateTime(2026, 9, 24, 18, 45)),
      _call('a', at: DateTime(2026, 9, 24, 18, 41)),
      _call('z', at: DateTime(2026, 9, 23, 23, 59)),
    ];
    final day = callsOnDay(
      log,
      conversationId: 'conv1',
      day: DateTime(2026, 9, 24),
    );
    expect(day.map((c) => c.id), ['a', 'b', 'c']);
  });

  test('durations read like WhatsApp', () {
    expect(callInfoDuration(24), '24s');
    expect(callInfoDuration(180), '3m 0s');
    expect(callInfoDuration(92), '1m 32s');
    expect(callInfoDuration(3720), '1h 2m');
  });

  test('the right column: duration, or why it never started', () {
    final at = DateTime(2026, 9, 24, 18);
    expect(callInfoOutcome(_call('a', at: at, duration: 75), 'en'), '1m 15s');
    expect(callInfoOutcome(_call('b', at: at, missed: true), 'en'), '');
    expect(
      callInfoOutcome(_call('c', at: at, direction: 'outgoing'), 'en'),
      'No answer',
    );
    expect(callInfoDirection(_call('d', at: at), 'en'), 'Incoming');
  });
}
