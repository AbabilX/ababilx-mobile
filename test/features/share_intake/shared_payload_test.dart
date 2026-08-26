import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/share_intake/data/shared_payload.dart';
import 'package:ababilx/shared/media/picked_media_file.dart';

/// Parses the JSON `ShareIntakeBridge.parse` (Kotlin) produces. The shape is
/// the contract between the two halves of this feature, so these cases are
/// written as the raw payload native actually sends, not as Dart objects.
String payloadJson({String text = '', List<Map<String, Object?>> files = const []}) =>
    jsonEncode({'text': text, 'files': files});

Map<String, Object?> file({
  String uri = 'content://media/external/file/1',
  String name = 'thing.bin',
  String mimeType = '',
  int size = 1024,
}) => {'uri': uri, 'name': name, 'mimeType': mimeType, 'size': size};

void main() {
  group('tryParse', () {
    test('text-only share carries no files', () {
      final payload = SharedPayload.tryParse(
        payloadJson(text: 'https://ababilx.com'),
      )!;

      expect(payload.files, isEmpty);
      expect(payload.text, 'https://ababilx.com');
      expect(payload.hasFiles, isFalse);
      expect(payload.isEmpty, isFalse);
    });

    test('nothing shared reads as no share at all', () {
      expect(SharedPayload.tryParse(null), isNull);
      expect(SharedPayload.tryParse(''), isNull);
      expect(SharedPayload.tryParse(payloadJson()), isNull);
      expect(SharedPayload.tryParse(payloadJson(text: '   ')), isNull);
    });

    test('malformed JSON is a missing share, never a crash', () {
      expect(SharedPayload.tryParse('not json at all'), isNull);
      expect(SharedPayload.tryParse('[1,2,3]'), isNull);
      expect(SharedPayload.tryParse('{"files": "nope"}'), isNull);
    });

    test('an entry with no uri is dropped', () {
      final payload = SharedPayload.tryParse(
        payloadJson(files: [file(uri: ''), file(name: 'kept.txt')]),
      )!;

      expect(payload.files.map((f) => f.fileName), ['kept.txt']);
    });

    test('keeps the URI rather than a path, so nothing is copied yet', () {
      final payload = SharedPayload.tryParse(
        payloadJson(
          files: [
            file(
              uri: 'content://com.android.providers.media.documents/document/image%3A42',
              name: 'holiday.jpg',
              mimeType: 'image/jpeg',
              size: 2048,
            ),
          ],
        ),
      )!;

      final shared = payload.files.single;
      expect(shared.uri, startsWith('content://'));
      expect(shared.fileName, 'holiday.jpg');
      expect(shared.contentType, 'image/jpeg');
      expect(shared.sizeBytes, 2048);
      expect(shared.isImage, isTrue);
      expect(shared.hasPreview, isTrue);
    });
  });

  group('content type', () {
    test('falls back to the extension when the sender declares nothing useful', () {
      final payload = SharedPayload.tryParse(
        payloadJson(
          files: [
            file(uri: 'content://a', name: 'invoice.pdf', mimeType: '*/*'),
            file(
              uri: 'content://b',
              name: 'shot.png',
              mimeType: 'application/octet-stream',
            ),
            file(uri: 'content://c', name: 'clip.mp4', mimeType: ''),
          ],
        ),
      )!;

      expect(payload.files[0].contentType, 'application/pdf');
      expect(payload.files[1].contentType, 'image/png');
      expect(payload.files[2].contentType, 'video/mp4');
      expect(payload.files[2].isVideo, isTrue);
    });

    test('an unnamed file still gets a name', () {
      final payload = SharedPayload.tryParse(
        payloadJson(files: [file(uri: 'content://a', name: '   ')]),
      )!;

      expect(payload.files.single.fileName, 'shared-file');
    });
  });

  group('size', () {
    test('flags oversized files instead of dropping them silently', () {
      final payload = SharedPayload.tryParse(
        payloadJson(
          files: [
            file(uri: 'content://small', name: 'small.txt', size: 16),
            file(
              uri: 'content://huge',
              name: 'huge.bin',
              size: maxWorkspaceAttachmentBytes + 1,
            ),
          ],
        ),
      )!;

      expect(payload.files, hasLength(2));
      expect(payload.sendableFiles.map((f) => f.fileName), ['small.txt']);
      expect(payload.oversizedCount, 1);
    });

    test('an unknown size is not treated as too large', () {
      // Providers are allowed to report nothing; the real length is checked
      // after the copy, in the sender.
      final payload = SharedPayload.tryParse(
        payloadJson(files: [file(uri: 'content://a', size: -1)]),
      )!;

      expect(payload.files.single.sizeBytes, -1);
      expect(payload.sendableFiles, hasLength(1));
      expect(payload.oversizedCount, 0);
    });
  });
}
