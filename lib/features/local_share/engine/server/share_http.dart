import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Reads a JSON body of at most [maxBytes]. Null for anything longer, or not
/// JSON — the caller answers 400 and never sees a partial body.
Future<Object?> readShareJson(HttpRequest request, int maxBytes) async {
  if (request.contentLength > maxBytes) return null;
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request) {
    if (builder.length + chunk.length > maxBytes) return null;
    builder.add(chunk);
  }
  try {
    return jsonDecode(utf8.decode(builder.takeBytes()));
  } catch (_) {
    return null;
  }
}

Future<void> replyShare(
  HttpRequest request,
  int status, [
  Map<String, Object?> body = const {},
]) async {
  try {
    final response = request.response;
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  } catch (_) {
    // The other side hung up; there is nobody to tell.
  }
}

Future<void> replyShareError(HttpRequest request, int status, String error) =>
    replyShare(request, status, {'error': error});
