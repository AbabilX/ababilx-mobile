import 'dart:convert';

import 'khaam_payload.dart';

/// Chat-list line for a Khaam body, or null when [body] is not one.
///
/// The message stays hidden until [reveal] says this phone may show it — the
/// sender's own card, or one already scratched open here. Anything else reads
/// as the bare label, so the list never spoils the surprise.
///
/// The sidebar row can carry the body cut at 120 characters, and a Khaam's
/// readable paragraph sits after its `attrs` block, so the generic TipTap
/// recovery finds nothing. A whole body parses normally; a cut one has its
/// `id` and `message` read straight out of the fragment.
String? khaamPreviewText(
  String body, {
  String lang = 'bn',
  bool Function(String id)? reveal,
}) {
  if (!body.contains('"jpack"')) return null;
  final label = khaamLabel(lang);
  final payload = KhaamPayload.tryParse(body);
  if (payload != null) {
    final show = reveal?.call(payload.id) ?? false;
    return show ? _line(label, payload.message) : label;
  }
  if (!RegExp(r'"type"\s*:\s*"doc"').hasMatch(body)) return null;
  final id = RegExp(r'"id"\s*:\s*"([^"\\]+)"').firstMatch(body)?.group(1);
  if (id == null || !(reveal?.call(id) ?? false)) return label;
  final match = RegExp(
    r'"message"\s*:\s*"((?:\\.|[^"\\])*)("?)',
  ).firstMatch(body);
  if (match == null) return label;
  var raw = match.group(1) ?? '';
  final complete = (match.group(2) ?? '').isNotEmpty;
  if (raw.endsWith(r'\')) raw = raw.substring(0, raw.length - 1);
  var text = raw;
  try {
    text = jsonDecode('"$raw"') as String;
  } catch (_) {}
  text = text.trim();
  if (!complete && text.isNotEmpty) text = '$text…';
  return _line(label, text);
}

String _line(String label, String message) {
  final text = message.trim();
  return text.isEmpty ? label : '$label · $text';
}
