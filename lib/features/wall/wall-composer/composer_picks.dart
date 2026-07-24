import 'package:flutter/material.dart';

import '../../team/data/models/team_models.dart';
import '../data/models/wall_models.dart';
import 'composer_trigger.dart';

List<TeamMember> filterMentionMembers(List<TeamMember> all, String q) {
  final lower = q.toLowerCase();
  final filtered = lower.isEmpty
      ? all
      : all.where((m) => m.displayName.toLowerCase().contains(lower));
  return filtered.take(8).toList();
}

List<WallCategory> filterWallCategories(List<WallCategory> all, String q) {
  final lower = q.toLowerCase();
  final filtered = lower.isEmpty
      ? all
      : all.where(
          (c) =>
              c.label.toLowerCase().contains(lower) ||
              c.slug.toLowerCase().contains(lower),
        );
  return filtered.take(8).toList();
}

void insertComposerChar(TextEditingController ctrl, String ch) {
  final t = ctrl.text;
  final at = ctrl.selection.isValid ? ctrl.selection.start : t.length;
  ctrl.value = TextEditingValue(
    text: '${t.substring(0, at)}$ch${t.substring(at)}',
    selection: TextSelection.collapsed(offset: at + ch.length),
  );
}

void applyCategoryPick(
  TextEditingController ctrl, {
  required WallCategory next,
  WallCategory? previous,
}) {
  if (previous != null && previous.label != next.label) {
    final cleaned = ctrl.text
        .replaceAll('#${previous.label} ', '')
        .replaceAll('#${previous.label}', '');
    ctrl.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
  final t = detectComposerTrigger(
    ctrl.text,
    ctrl.selection.baseOffset.clamp(0, ctrl.text.length),
  );
  if (t != null && !t.isMention) {
    applyComposerTrigger(ctrl, t, next.label);
    return;
  }
  final base = ctrl.text.trimRight();
  final text = base.isEmpty ? '#${next.label} ' : '$base #${next.label} ';
  ctrl.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}
