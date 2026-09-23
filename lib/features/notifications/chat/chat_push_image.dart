import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../messages/data/chat_repository.dart';

/// Must match `android:authorities` of `NotificationImageProvider` in
/// AndroidManifest.xml and the `<cache-path>` in notification_image_paths.xml.
const _authority = 'com.ababilx.app.notificationimages';
const _dirName = 'notification_images';

/// Larger than any photo the composer sends at Standard quality; a High
/// original past it just stays a text line.
const _maxBytes = 8 * 1024 * 1024;

/// A tray picture is only needed while the entry is up.
const _keepFor = Duration(days: 2);

/// Fetches the photo of message [messageId] for its tray entry and returns a
/// `content://` URI Android can draw, or null.
///
/// The push never carries the file URL — the object is on a public CDN and a
/// push travels through Google — so the URL is read from our own API. The
/// bytes are fetched with a bare client: the CDN must never see the JWT.
///
/// Android only. Android 9+ grants SystemUI read access to URIs inside a
/// posted MessagingStyle notification by itself, so no explicit grant is made.
Future<String?> fetchChatPushImage({
  required String conversationId,
  required String messageId,
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (!Platform.isAndroid) return null;
  try {
    return await _fetch(conversationId, messageId).timeout(timeout);
  } catch (_) {
    return null;
  }
}

Future<String?> _fetch(String conversationId, String messageId) async {
  final url = await _imageUrl(conversationId, messageId);
  if (url == null) return null;

  final dir = Directory('${(await getTemporaryDirectory()).path}/$_dirName');
  await dir.create(recursive: true);
  await _sweep(dir);

  final file = File('${dir.path}/${_safeName(messageId)}.jpg');
  if (!await file.exists() || await file.length() == 0) {
    final res = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty || bytes.length > _maxBytes) {
      return null;
    }
    await file.writeAsBytes(bytes, flush: true);
  }
  return 'content://$_authority/images/${file.uri.pathSegments.last}';
}

/// The first photo's URL on [messageId], from the newest page of the
/// conversation — a just-pushed message is at its head.
Future<String?> _imageUrl(String conversationId, String messageId) async {
  const storage = SecureStorage(FlutterSecureStorage());
  final repo = ChatRepository(ApiClient(storage));
  final page = await repo.listMessages(conversationId, limit: 20);
  for (final message in page.messages) {
    if (message.id != messageId) continue;
    for (final attachment in message.attachments) {
      final url = attachment.fileUrl;
      // A photo its sender restricted (privacy mode) never goes to the
      // tray: it would be a copy outside the app, drawn over the lock screen.
      if (attachment.isImage &&
          !attachment.locked &&
          !attachment.isProtected &&
          url.startsWith('https://')) {
        return url;
      }
    }
    return null;
  }
  return null;
}

String _safeName(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

Future<void> _sweep(Directory dir) async {
  final cutoff = DateTime.now().subtract(_keepFor);
  try {
    await for (final entry in dir.list()) {
      if (entry is File && (await entry.lastModified()).isBefore(cutoff)) {
        await entry.delete();
      }
    }
  } catch (_) {}
}
