import 'package:flutter/foundation.dart';

/// One line per call-ownership event, on the same `[voice-call]` tag as
/// `voiceCallLog` so a single filter shows both.
///
/// Written to answer four questions after the fact: who took a call from
/// `connected` to `idle`, which call a callback belonged to, which call the
/// engine was built for, and whether stale work was refused. Emitted on
/// transitions only — never per frame, per signal or per heartbeat.
///
/// [callId] is the call the event is about; [targetCallId] is the call a
/// refused operation named, and [activeCallId] the one in state at that
/// moment. [generation] is the notifier's operation counter.
void callTrace(
  String event, {
  String? callId,
  String? targetCallId,
  String? activeCallId,
  String? engineCallId,
  String? previousPhase,
  String? newPhase,
  String? operation,
  int? generation,
  String? source,
  String? reason,
}) {
  final parts = <String>[
    '[voice-call]',
    event,
    'ts=${DateTime.now().toIso8601String()}',
    if (operation != null) 'operation=$operation',
    if (callId != null) 'callId=$callId',
    if (targetCallId != null) 'targetCallId=$targetCallId',
    if (activeCallId != null) 'activeCallId=$activeCallId',
    if (engineCallId != null) 'engineCallId=$engineCallId',
    if (previousPhase != null) 'previousPhase=$previousPhase',
    if (newPhase != null) 'newPhase=$newPhase',
    if (generation != null) 'generation=$generation',
    if (source != null) 'source=$source',
    if (reason != null) 'reason=$reason',
  ];
  debugPrint(parts.join(' '));
}
