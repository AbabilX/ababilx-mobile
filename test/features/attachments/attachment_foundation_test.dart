import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/attachments/services/attachment_failure.dart';
import 'package:ababilx/features/attachments/services/attachment_policy.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageAttachment attachment({
  String name = 'photo.jpg',
  String type = 'image/jpeg',
  int bytes = 1024,
  String url = 'https://assetsbox.ababilx.com/chat/photo.jpg',
  bool locked = false,
}) => ChatMessageAttachment(
  id: 'a1',
  messageId: 'm1',
  fileName: name,
  fileUrl: url,
  contentType: type,
  sizeBytes: bytes,
  uploadedBy: 'u1',
  createdAt: '',
  locked: locked,
);

void main() {
  group('attachment URL key', () {
    test('normalizes host and strips query and fragment', () {
      const first = 'HTTPS://ASSETSBOX.ABABILX.COM/chat/A.jpg?v=2#preview';
      const second = 'https://assetsbox.ababilx.com/chat/A.jpg';
      expect(normaliseAttachmentUrl(first), second);
      expect(attachmentUrlKey(first), attachmentUrlKey(second));
      expect(attachmentUrlKey(first), hasLength(40));
    });

    test('keeps case-sensitive object paths distinct', () {
      expect(
        attachmentUrlKey('https://example.com/A.jpg'),
        isNot(attachmentUrlKey('https://example.com/a.jpg')),
      );
    });
  });

  group('auto-download policy', () {
    test('allows small images and voice notes', () {
      expect(shouldAutoDownload(attachment()), isTrue);
      expect(
        shouldAutoDownload(attachment(name: 'voice.m4a', type: 'audio/mp4')),
        isTrue,
      );
    });

    test('blocks expensive or unavailable attachments', () {
      expect(
        shouldAutoDownload(attachment(name: 'clip.mp4', type: 'video/mp4')),
        isFalse,
      );
      expect(shouldAutoDownload(attachment(locked: true)), isFalse);
      expect(shouldAutoDownload(attachment(bytes: 6 * 1024 * 1024)), isFalse);
    });
  });

  group('failure classification', () {
    test('retries timeouts and server failures', () {
      final timeout = DioException(
        requestOptions: RequestOptions(path: '/asset'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(classifyDownloadError(timeout).permanent, isFalse);
      final server = DioException.badResponse(
        statusCode: 503,
        requestOptions: RequestOptions(path: '/asset'),
        response: Response(
          requestOptions: RequestOptions(path: '/asset'),
          statusCode: 503,
        ),
      );
      expect(classifyDownloadError(server).permanent, isFalse);
    });

    test('does not retry a missing public object', () {
      final missing = DioException.badResponse(
        statusCode: 404,
        requestOptions: RequestOptions(path: '/asset'),
        response: Response(
          requestOptions: RequestOptions(path: '/asset'),
          statusCode: 404,
        ),
      );
      final failure = classifyDownloadError(missing);
      expect(failure.code, 'http_404');
      expect(failure.permanent, isTrue);
    });
  });
}
