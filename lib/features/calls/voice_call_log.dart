import 'package:flutter/foundation.dart';

/// Structured debug logs for voice-call race diagnosis.
void voiceCallLog(
  String action, {
  String? callId,
  String? phase,
  String? source,
  String? reason,
  bool? suppress,
}) {
  final parts = <String>[
    '[voice-call]',
    action,
    if (callId != null) 'callId=$callId',
    if (phase != null) 'phase=$phase',
    if (source != null) 'source=$source',
    if (reason != null) 'reason=$reason',
    if (suppress != null) 'suppress=$suppress',
  ];
  debugPrint(parts.join(' '));
}
