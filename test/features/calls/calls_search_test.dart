import 'package:ababilx/features/calls/calls-list/calls_search.dart';
import 'package:ababilx/features/calls/data/models/call_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

CallLogEntry _call(String id, String title) => CallLogEntry(
  id: id,
  kind: 'direct',
  scope: 'personal',
  conversationId: 'conv-$id',
  mode: 'audio',
  status: 'ended',
  direction: 'incoming',
  missed: false,
  title: title,
  startedAt: DateTime(2026, 9, 29),
);

void main() {
  final calls = [
    _call('1', 'Murad Hossain'),
    _call('2', '𝕄𝕦𝕣𝕒𝕕 Alt'),
    _call('3', 'Ada Lovelace'),
    _call('4', 'জীবন'),
  ];

  test('an empty query keeps every call', () {
    expect(searchCallLog(calls, '  '), same(calls));
  });

  test('matches by name, ignoring case and styled letters', () {
    final ids = searchCallLog(calls, 'murad').map((c) => c.id);
    expect(ids, ['1', '2']);
  });

  test('matches Bangla names', () {
    expect(searchCallLog(calls, 'জীব').map((c) => c.id), ['4']);
  });

  test('no match is an empty list', () {
    expect(searchCallLog(calls, 'zzz'), isEmpty);
  });
}
