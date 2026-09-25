import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';

import '../../ghost/native/ghost_blobs.dart';

/// A locked chat's pictures and files, held in this process's memory and
/// nowhere else. Nothing here writes a file: not the attachment store, not an
/// HTTP cache, not a temp copy.
///
/// Fetched with a bare Dio — attachment URLs are public objects, and the API
/// client's auth interceptor must never reach them. Bounded, oldest first; an
/// evicted picture is simply fetched again. [release] runs when every locked
/// chat is closed again: the arrays are zeroed, decoded images dropped and
/// the native memory blobs (PDFs, files opened elsewhere) overwritten.
abstract final class RamMediaCache {
  /// Above this a file is not pulled into memory at all.
  static const maxFileBytes = 80 * 1024 * 1024;
  static const _budget = 96 * 1024 * 1024;

  static final _bytes = <String, Uint8List>{};
  static final _inFlight = <String, Future<Uint8List>>{};
  static final _blobKeys = <String>{};
  static int _total = 0;
  static int _generation = 0;

  static final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 20)),
  );

  static Uint8List? peek(String url) => _bytes[url];

  static Future<Uint8List> fetch(String url) {
    final hit = _bytes.remove(url);
    if (hit != null) {
      _bytes[url] = hit; // most recent last
      return Future.value(hit);
    }
    return _inFlight[url] ??= _download(
      url,
    ).whenComplete(() => _inFlight.remove(url));
  }

  static Future<Uint8List> _download(String url) async {
    final generation = _generation;
    final res = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    if (data == null || data.isEmpty) throw StateError('empty attachment');
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    // A release while this was downloading means the chat closed: hand the
    // bytes to whoever waited, but keep nothing.
    if (generation != _generation) return bytes;
    _bytes[url] = bytes;
    _total += bytes.length;
    while (_total > _budget && _bytes.length > 1) {
      final oldest = _bytes.keys.first;
      _total -= _bytes.remove(oldest)!.length;
    }
    return bytes;
  }

  /// The key a file is held under natively (GhostBlobs), remembered so
  /// [release] can drop exactly these and leave a Ghost session alone.
  static String blobKey(String url) {
    final key = 'locked-chat:$url';
    _blobKeys.add(key);
    return key;
  }

  static Future<void> release() async {
    _generation++;
    for (final bytes in _bytes.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _bytes.clear();
    _total = 0;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    final keys = _blobKeys.toList();
    _blobKeys.clear();
    await GhostBlobs.drop(keys);
  }
}
