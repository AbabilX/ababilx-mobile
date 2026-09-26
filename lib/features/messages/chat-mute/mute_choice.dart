import 'package:intl/intl.dart';

import '../data/models/chat_models.dart';

/// What the mute sheet chose (server migration 0162).
///
/// A preset travels as `for_seconds` so the SERVER's clock measures the hour —
/// a phone whose clock is off would otherwise mute for the wrong length. A
/// custom time is an exact moment the person picked, so it travels as `until`.
/// Neither = until unmuted ("Always").
class MuteChoice {
  const MuteChoice._({this.duration, this.until, this.mentionsOnly = false});

  const MuteChoice.forDuration(Duration d) : this._(duration: d);
  const MuteChoice.always() : this._();
  const MuteChoice.mentionsOnly() : this._(mentionsOnly: true);
  MuteChoice.until(DateTime at) : this._(until: at);

  final Duration? duration;
  final DateTime? until;
  final bool mentionsOnly;

  Map<String, dynamic> toBody() => {
    'muted': true,
    'mode': mentionsOnly ? 'mentions' : 'all',
    if (duration != null) 'for_seconds': duration!.inSeconds,
    if (until != null) 'until': until!.toUtc().toIso8601String(),
  };
}

/// The server's answer to a mute write, applied to the cached row.
class MuteResult {
  const MuteResult({required this.muted, this.until, this.mode = 'all'});

  factory MuteResult.fromJson(Map<String, dynamic> json) => MuteResult(
    muted: json['muted'] as bool? ?? false,
    until: DateTime.tryParse(json['muted_until'] as String? ?? '')?.toLocal(),
    mode: json['mute_mode'] as String? ?? 'all',
  );

  static const unmuted = MuteResult(muted: false);

  final bool muted;
  final DateTime? until;
  final String mode;
}

/// Reads a row's mute as of now. A timed mute lapses on its own and nothing
/// tells the phone, so every surface asks here rather than reading `muted`.
extension ChatConversationMute on ChatConversation {
  bool get isMutedNow {
    if (!muted) return false;
    final end = mutedUntil;
    return end == null || end.isAfter(DateTime.now());
  }

  bool get isMentionsOnlyMute => isMutedNow && muteMode == 'mentions';

  /// One line saying what the mute is, or null when not muted.
  String? get muteStatusLabel {
    if (!isMutedNow) return null;
    if (muteMode == 'mentions') return 'Only mentions';
    final end = mutedUntil;
    if (end == null) return 'Muted';
    return 'Muted until ${formatMuteEnd(end)}';
  }
}

/// "5:30 PM" today, "tomorrow 9:00 AM", "Mon 9:00 AM" this week, else a date.
String formatMuteEnd(DateTime end, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // Calendar days counted in UTC: a local midnight-to-midnight across a DST
  // change is 23 h, which `inDays` reads as 0 and "tomorrow" as today.
  final days = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final time = DateFormat('h:mm a').format(end);
  if (days <= 0) return time;
  if (days == 1) return 'tomorrow $time';
  if (days < 7) return '${DateFormat('EEE').format(end)} $time';
  if (end.year == today.year) return DateFormat('d MMM, h:mm a').format(end);
  return DateFormat('d MMM yyyy, h:mm a').format(end);
}
