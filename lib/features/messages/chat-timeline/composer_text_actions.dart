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

void insertComposerEmoji(TextEditingController ctrl, String emoji) {
  final t = ctrl.text;
  final at = ctrl.selection.isValid ? ctrl.selection.start : t.length;
  ctrl.value = TextEditingValue(
    text: '${t.substring(0, at)}$emoji${t.substring(at)}',
    selection: TextSelection.collapsed(offset: at + emoji.length),
  );
}
