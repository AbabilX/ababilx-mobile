import 'package:ababilx/features/messages/chat-mute/mute_choice.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _conv({
  bool muted = false,
  DateTime? until,
  String mode = 'all',
}) => ChatConversation(
  id: 'c1',
  teamId: '',
  type: 'group',
  createdAt: '2026-09-27T00:00:00Z',
  muted: muted,
  mutedUntil: until,
  muteMode: mode,
);

void main() {
  test('a preset travels as for_seconds, a custom time as until', () {
    expect(const MuteChoice.forDuration(Duration(hours: 8)).toBody(), {
      'muted': true,
      'mode': 'all',
      'for_seconds': 28800,
    });
    expect(const MuteChoice.always().toBody(), {'muted': true, 'mode': 'all'});
    expect(const MuteChoice.mentionsOnly().toBody(), {
      'muted': true,
      'mode': 'mentions',
    });
    final at = DateTime.utc(2026, 10, 1, 9);
    expect(MuteChoice.until(at).toBody()['until'], '2026-10-01T09:00:00.000Z');
  });

  test('a lapsed timed mute reads as unmuted', () {
    final past = DateTime.now().subtract(const Duration(minutes: 1));
    final later = DateTime.now().add(const Duration(hours: 1));
    expect(_conv().isMutedNow, isFalse);
    expect(_conv(muted: true).isMutedNow, isTrue);
    expect(_conv(muted: true, until: later).isMutedNow, isTrue);
    expect(_conv(muted: true, until: past).isMutedNow, isFalse);
    expect(_conv(muted: true, mode: 'mentions').isMentionsOnlyMute, isTrue);
    expect(
      _conv(muted: true, until: past, mode: 'mentions').isMentionsOnlyMute,
      isFalse,
    );
  });

  test('status label names the kind of mute', () {
    expect(_conv().muteStatusLabel, isNull);
    expect(_conv(muted: true).muteStatusLabel, 'Muted');
    expect(
      _conv(muted: true, mode: 'mentions').muteStatusLabel,
      'Only mentions',
    );
    final later = DateTime.now().add(const Duration(days: 3));
    expect(
      _conv(muted: true, until: later).muteStatusLabel,
      startsWith('Muted until '),
    );
  });

  test('mute end reads as time, tomorrow, weekday, then date', () {
    final now = DateTime(2026, 9, 27, 10);
    expect(formatMuteEnd(DateTime(2026, 9, 27, 17, 30), now: now), '5:30 PM');
    expect(
      formatMuteEnd(DateTime(2026, 9, 28, 9), now: now),
      'tomorrow 9:00 AM',
    );
    expect(formatMuteEnd(DateTime(2026, 9, 30, 9), now: now), 'Wed 9:00 AM');
    expect(formatMuteEnd(DateTime(2026, 11, 2, 9), now: now), '2 Nov, 9:00 AM');
    expect(
      formatMuteEnd(DateTime(2027, 1, 2, 9), now: now),
      '2 Jan 2027, 9:00 AM',
    );
  });

  test('a day across a DST change still reads as tomorrow', () {
    // Pure calendar arithmetic: a 23-hour local day must not collapse.
    final now = DateTime(2026, 3, 28, 22);
    expect(
      formatMuteEnd(DateTime(2026, 3, 29, 9), now: now),
      'tomorrow 9:00 AM',
    );
    expect(formatMuteEnd(DateTime(2026, 3, 28, 23), now: now), '11:00 PM');
  });

  test('server answer parses and an unmute clears the end time', () {
    final r = MuteResult.fromJson({
      'muted': true,
      'muted_until': '2026-10-01T09:00:00Z',
      'mute_mode': 'all',
    });
    expect(r.muted, isTrue);
    expect(r.until!.toUtc(), DateTime.utc(2026, 10, 1, 9));
    final muted = _conv(muted: true, until: r.until);
    final cleared = muted.copyWith(
      muted: false,
      clearMutedUntil: true,
      muteMode: 'all',
    );
    expect(cleared.mutedUntil, isNull);
    expect(cleared.isMutedNow, isFalse);
  });
}
