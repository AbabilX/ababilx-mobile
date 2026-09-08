/// Fetches a page and reads its Open Graph tags — on this device, the way
/// Signal-Android does it (`LinkPreviewRepository`), not through a proxy.
///
/// **The reader pays for it, and that is the accepted cost.** Signal unfurls in
/// the COMPOSER, on the sender's machine, and ships the card inside the
/// message; a receiver never makes a request, and the setting is off by
/// default. We unfurl on read, so the link's host learns this phone's address
/// and the moment the chat was opened. That is what buys previews with no
/// server in the path and no third-party quota.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'link_preview_data.dart';
import 'link_preview_parse.dart';
import 'link_safety.dart';

/// Signal's `FAILSAFE_MAX_TEXT_SIZE`. Worth keeping exactly: YouTube serves an
/// app shell to anything it does not recognise as a crawler, with `og:title`
/// some 700 KB in — a smaller cap silently loses YouTube.
const _maxHtmlBytes = 2 * 1024 * 1024;

/// Signal's `FAILSAFE_MAX_IMAGE_SIZE`.
const maxPreviewImageBytes = 2 * 1024 * 1024;

/// OkHttp's own default, and the number Signal inherits.
const _maxRedirects = 20;

/// Honest, and named after us. Signal sends `WhatsApp/2`; large sites do key
/// their Open Graph markup on the user agent — Facebook answers a browser
/// string with 400 on a `/share/` link — but wearing another company's crawler
/// name is not something to build on. This is the string the desktop app and
/// the server both send, so all three get the same markup back.
const previewUserAgent =
    'Mozilla/5.0 (compatible; AbabilXBot/1.0; +https://ababilx.com/bot)';

const _timeout = Duration(seconds: 10);

/// Returns null when there is nothing to show. A login wall, a dead host and a
/// page with no tags all mean the same thing on screen: no card under a link
/// that is still perfectly clickable.
Future<LinkPreviewData?> fetchLinkPreview(String url, {Dio? client}) async {
  if (!isValidPreviewUrl(url)) return null;

  final dio = client ?? Dio();
  var target = url;

  for (var hop = 0; hop <= _maxRedirects; hop++) {
    final response = await dio.getUri<ResponseBody>(
      Uri.parse(target),
      options: Options(
        responseType: ResponseType.stream,
        // Redirects are followed BY HAND so every hop is re-checked. Following
        // them inside the client would let one https link land on a private
        // address two jumps later — Signal guards the same seam with
        // LinkPreviewRedirectValidationInterceptor.
        followRedirects: false,
        validateStatus: (_) => true,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
        headers: {
          'User-Agent': previewUserAgent,
          'Accept': 'text/html,application/xhtml+xml',
        },
      ),
    );

    final status = response.statusCode ?? 0;
    final location = _header(response, 'location');
    if (status >= 300 && status < 400 && location != null) {
      await _drain(response);
      final next = Uri.parse(target).resolve(location).toString();
      if (!isValidPreviewUrl(next)) return null;
      target = next;
      continue;
    }
    if (status < 200 || status >= 300) {
      await _drain(response);
      return null;
    }

    final contentType = _header(response, 'content-type')?.toLowerCase() ?? '';

    // Linked straight at a picture. Signal makes it the card and uses the file
    // name as the title, "which is no worse than the body of the message".
    if (contentType.startsWith('image/')) {
      await _drain(response);
      return LinkPreviewData(url: url, title: _fileName(target), imageUrl: target);
    }
    if (contentType.isNotEmpty && !contentType.contains('html')) {
      await _drain(response);
      return null;
    }

    final bytes = await _readCapped(response, _maxHtmlBytes);
    // Malformed input is allowed through rather than thrown on: the read is cut
    // at a byte boundary, so the last character of a capped page is usually
    // half of one. Charset detection is NOT ported — a page declaring anything
    // but UTF-8 loses its accents, not its card.
    final html = const Utf8Decoder(allowMalformed: true).convert(bytes);
    final preview = parseLinkPreview(url, html);
    return preview.isEmpty ? null : preview;
  }

  return null;
}

String? _header(Response<ResponseBody> response, String name) =>
    response.headers.value(name);

Future<Uint8List> _readCapped(Response<ResponseBody> response, int limit) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response.data!.stream) {
    builder.add(chunk);
    if (builder.length >= limit) break;
  }
  final bytes = builder.takeBytes();
  return bytes.length <= limit ? bytes : Uint8List.sublistView(bytes, 0, limit);
}

Future<void> _drain(Response<ResponseBody> response) async {
  try {
    await response.data?.stream.drain<void>();
  } catch (_) {
    // The body of a redirect or an error is of no interest either way.
  }
}

String? _fileName(String url) {
  final segments = Uri.tryParse(url)?.pathSegments ?? const [];
  for (final segment in segments.reversed) {
    if (segment.isNotEmpty) return segment;
  }
  return null;
}
