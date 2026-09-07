import 'package:flutter/material.dart';

/// The call surface is dark in both themes, the way Signal's is. This is the
/// one place in the app where the "use Theme.colorScheme" rule is deliberately
/// not followed — a call screen is always dark, and a light-theme surface
/// colour would wash out over the backdrop (see features/calls/CLAUDE.md).
class CallSurface {
  const CallSurface._();

  static const Color backdrop = Color(0xFF121214);
  static const Color tile = Color(0xFF26262B);
  static const Color panel = Color(0xFF1B1B1F);
  static const Color accent = Color(0xFF3AD07F);
  static const Color danger = Color(0xFFE2444F);
  static const Color hand = Color(0xFFF5C518);
  static const Color muted = Color(0xFFF0616B);
  static const Color faint = Color(0x99FFFFFF);
}

/// Column count that keeps tiles roughly square as a call fills up.
int callGridColumns(int count) {
  if (count <= 1) return 1;
  if (count <= 4) return 2;
  if (count <= 9) return 3;
  return 4;
}

String callInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

/// Wall-clock length of a call, from the row the server stamped.
String callElapsedLabel(DateTime? startedAt, {DateTime? now}) {
  if (startedAt == null) return '';
  final seconds = (now ?? DateTime.now()).difference(startedAt).inSeconds;
  if (seconds < 0) return '0:00';
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  String pad(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${pad(minutes % 60)}:${pad(seconds % 60)}'
      : '$minutes:${pad(seconds % 60)}';
}

String participantCountLabel(int count) =>
    count == 1 ? '1 person' : '$count people';
