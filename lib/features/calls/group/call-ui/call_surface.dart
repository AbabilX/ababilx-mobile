import 'package:flutter/material.dart';

/// Colours for the call surface, taken from the app theme.
///
/// The DM call screens are hardcoded dark on purpose — they sit on a blurred
/// photograph of the caller (see features/calls/CLAUDE.md). A group call has
/// no such backdrop: it is one route inside a themed app, so a permanently
/// dark takeover reads as a bug in light mode. Resolve once per build with
/// [CallColors.of] rather than reaching for `Theme.of` in every leaf.
class CallColors {
  const CallColors._({
    required this.backdrop,
    required this.tile,
    required this.panel,
    required this.onSurface,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.hand,
    required this.muted,
    required this.chip,
    required this.onChip,
  });

  factory CallColors.of(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CallColors._(
      backdrop: colors.surface,
      tile: colors.surfaceContainerHighest,
      panel: colors.surfaceContainerHigh,
      onSurface: colors.onSurface,
      faint: colors.onSurfaceVariant,
      accent: colors.primary,
      onAccent: colors.onPrimary,
      danger: colors.error,
      hand: colors.tertiary,
      muted: colors.error,
      // Overlay chip on a tile: sits over an avatar, so it stays translucent
      // and takes its contrast from the theme's inverse pair.
      chip: colors.inverseSurface.withValues(alpha: 0.82),
      onChip: colors.onInverseSurface,
    );
  }

  final Color backdrop;
  final Color tile;
  final Color panel;
  final Color onSurface;
  final Color faint;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color hand;
  final Color muted;
  final Color chip;
  final Color onChip;
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
