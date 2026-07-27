import 'package:flutter/material.dart';

void wrapComposerBold(TextEditingController ctrl) {
  final t = ctrl.text;
  final sel = ctrl.selection;
  if (!sel.isValid) return;
  final inner = sel.textInside(t);
  final next = '${sel.textBefore(t)}*$inner*${sel.textAfter(t)}';
  ctrl.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: sel.start + inner.length + 2),
  );
}

void insertComposerAt(TextEditingController ctrl) {
  final t = ctrl.text;
  final at = ctrl.selection.isValid ? ctrl.selection.start : t.length;
  ctrl.value = TextEditingValue(
    text: '${t.substring(0, at)}@${t.substring(at)}',
    selection: TextSelection.collapsed(offset: at + 1),
  );
}

void insertComposerText(TextEditingController ctrl, String snippet) {
  final t = ctrl.text;
  final at = ctrl.selection.isValid ? ctrl.selection.start : t.length;
  final before = t.substring(0, at);
  final after = t.substring(at);
  final needsPadBefore =
      before.isNotEmpty && !before.endsWith('\n') && !before.endsWith(' ');
  final insert = '${needsPadBefore ? '\n' : ''}$snippet';
  ctrl.value = TextEditingValue(
    text: '$before$insert$after',
    selection: TextSelection.collapsed(offset: before.length + insert.length),
  );
}

void insertComposerEmoji(TextEditingController ctrl, String emoji) {
  final t = ctrl.text;
  final at = ctrl.selection.isValid ? ctrl.selection.start : t.length;
  ctrl.value = TextEditingValue(
    text: '${t.substring(0, at)}$emoji${t.substring(at)}',
    selection: TextSelection.collapsed(offset: at + emoji.length),
  );
}
