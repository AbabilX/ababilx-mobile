import 'dart:convert';

import 'jpack_payload.dart';

const _label = '💌 JPack';

/// Chat-list line for a JPack body, or null when [body] is not one.
///
/// The sidebar row carries the body cut at 120 characters, and a JPack's
/// readable paragraph sits after its ~100-character `attrs` block, so the
/// generic TipTap recovery finds nothing. A whole body parses normally; a cut
/// one has its `message` read straight out of the fragment.
String? jpackPreviewText(String body) {
  if (!body.contains('"jpack"')) return null;
  final payload = JPackPayload.tryParse(body);
  if (payload != null) return _line(payload.message);
  final match = RegExp(
    r'"message"\s*:\s*"((?:\\.|[^"\\])*)("?)',
  ).firstMatch(body);
  if (match == null) {
    return RegExp(r'"type"\s*:\s*"doc"').hasMatch(body) ? _label : null;
  }
  var raw = match.group(1) ?? '';
  final complete = (match.group(2) ?? '').isNotEmpty;
  if (raw.endsWith(r'\')) raw = raw.substring(0, raw.length - 1);
  var text = raw;
  try {
    text = jsonDecode('"$raw"') as String;
  } catch (_) {}
  text = text.trim();
  if (!complete && text.isNotEmpty) text = '$text…';
  return _line(text);
}

String _line(String message) {
  final text = message.trim();
  return text.isEmpty ? _label : '$_label · $text';
}
