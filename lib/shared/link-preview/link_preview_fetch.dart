/// Fetches a page and reads its Open Graph tags — on this device, the way
/// the reference Android app does it (`LinkPreviewRepository`), not through a
/// proxy.
///
/// **The reader pays for it, and that is the accepted cost.** The reference app
/// unfurls in the COMPOSER, on the sender's machine, and ships the card inside
/// the message; a receiver never makes a request, and the setting is off by
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

/// The reference app's `FAILSAFE_MAX_TEXT_SIZE`. Worth keeping exactly: YouTube
/// serves an app shell to anything it does not recognise as a crawler, with
/// `og:title` some 700 KB in — a smaller cap silently loses YouTube.
const _maxHtmlBytes = 2 * 1024 * 1024;

/// The reference app's `FAILSAFE_MAX_IMAGE_SIZE`.
const maxPreviewImageBytes = 2 * 1024 * 1024;

/// OkHttp's own default, and the number the reference app inherits.
const _maxRedirects = 20;

/// Honest, and named after us. The reference app sends `WhatsApp/2`; large
/// sites do key their Open Graph markup on the user agent — Facebook answers a
/// browser string with 400 on a `/share/` link — but wearing another company's
/// crawler name is not something to build on. This is the string the desktop
/// app and the server both send, so all three get the same markup back.
const previewUserAgent =
    'Mozilla/5.0 (compatible; AbabilXBot/1.0; +https://ababilx.com/bot)';

const _timeout = Duration(seconds: 10);

/// Returns null when there is nothing to show. A login wall, a dead host and a
/// page with no tags all mean the same thing on screen: no card under a link
/// that is still perfectly clickable.
Future<LinkPreviewData?> fetchLinkPreview(String url, {Dio? client}) async {
  final opened = await openPreviewStream(
    url,
    accept: 'text/html,application/xhtml+xml',
    client: client,
  );
  if (opened == null) return null;

  final contentType = previewContentType(opened.response);

  // Linked straight at a picture. The reference app makes it the card and uses
  // the file name as the title, "which is no worse than the body of the
  // message".
  if (contentType.startsWith('image/')) {
    await drainPreviewBody(opened.response);
    return LinkPreviewData(
      url: url,
      title: _fileName(opened.finalUrl),
      imageUrl: opened.finalUrl,
    );
  }
  if (contentType.isNotEmpty && !contentType.contains('html')) {
    await drainPreviewBody(opened.response);
    return null;
  }

  final bytes = await readCappedBody(opened.response, _maxHtmlBytes);
  // Malformed input is allowed through rather than thrown on: the read is cut
  // at a byte boundary, so the last character of a capped page is usually
  // half of one. Charset detection is NOT ported — a page declaring anything
  // but UTF-8 loses its accents, not its card.
  final html = const Utf8Decoder(allowMalformed: true).convert(bytes);
  final preview = parseLinkPreview(url, html);
  return preview.isEmpty ? null : preview;
}

/// A response that survived every check, and the URL it actually came from.
class PreviewStream {
  const PreviewStream(this.response, this.finalUrl);

  final Response<ResponseBody> response;
  final String finalUrl;
}

/// Opens [url] and follows its redirects BY HAND, re-checking every hop.
///
/// The page and its picture go through this same door on purpose. An `og:image`
/// is written by whoever wrote the page, so it is exactly as untrusted as the
/// link that led here — handing it straight to an image widget would skip the
/// https rule, the reserved-domain list and the private-address refusal that
/// the page itself had to pass.
Future<PreviewStream?> openPreviewStream(
  String url, {
  required String accept,
  Dio? client,
}) async {
  if (!isValidPreviewUrl(url)) return null;

  final dio = client ?? Dio();
  var target = url;

  for (var hop = 0; hop <= _maxRedirects; hop++) {
    final response = await dio.getUri<ResponseBody>(
      Uri.parse(target),
      options: Options(
        responseType: ResponseType.stream,
        // Following redirects inside the client would let one https link land
        // on a private address two jumps later — the reference app guards the
        // same seam with LinkPreviewRedirectValidationInterceptor.
        followRedirects: false,
        validateStatus: (_) => true,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
        headers: {'User-Agent': previewUserAgent, 'Accept': accept},
      ),
    );

    final status = response.statusCode ?? 0;
    final location = response.headers.value('location');
    if (status >= 300 && status < 400 && location != null) {
      await drainPreviewBody(response);
      final next = Uri.parse(target).resolve(location).toString();
      if (!isValidPreviewUrl(next)) return null;
      target = next;
      continue;
    }
    if (status < 200 || status >= 300) {
      await drainPreviewBody(response);
      return null;
    }
    return PreviewStream(response, target);
  }

  return null;
}

String previewContentType(Response<ResponseBody> response) =>
    (response.headers.value('content-type') ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();

/// Reads at most [limit] bytes, chunk by chunk, so the ceiling holds whatever
/// the server claims its length to be.
Future<Uint8List> readCappedBody(
  Response<ResponseBody> response,
  int limit,
) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response.data!.stream) {
    builder.add(chunk);
    if (builder.length >= limit) break;
  }
  final bytes = builder.takeBytes();
  return bytes.length <= limit ? bytes : Uint8List.sublistView(bytes, 0, limit);
}

Future<void> drainPreviewBody(Response<ResponseBody> response) async {
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
