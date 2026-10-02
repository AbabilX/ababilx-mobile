import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../widgets/avatar_cache.dart';

/// Gets a picture's bytes for the avatar store: from the old
/// `flutter_cache_manager` store when it already holds them (so the first
/// launch on this build re-downloads nothing it had), else from the network.
///
/// No JWT: avatars are public CDN objects or Google profile pictures, and the
/// API's token has no business travelling to either.
class AvatarFetch {
  const AvatarFetch._();

  static const _maxBytes = 8 * 1024 * 1024;

  /// Google's CDN rejects bare Dart requests on some images; a browser user
  /// agent decodes them. Kept from the old `AppAvatar` headers.
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// A prefetch asks for every chat's picture at once; four at a time.
  static const _parallel = 4;
  static int _running = 0;
  static final List<Completer<void>> _waiting = [];

  static Future<Uint8List?> bytes(String url) async {
    final cached = await _fromOldCache(url);
    if (cached != null) return cached;
    if (_running < _parallel) {
      _running++;
    } else {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await _download(url);
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _running--;
      }
    }
  }

  static Future<Uint8List?> _fromOldCache(String url) async {
    try {
      final info = await AvatarCache.instance.getFileFromCache(url);
      final file = info?.file;
      if (file == null || !await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = _userAgent;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final out = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        out.add(chunk);
        if (out.length > _maxBytes) return null;
      }
      return out.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
