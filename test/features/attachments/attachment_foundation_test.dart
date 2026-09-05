import 'package:ababilx/core/network/network_class.dart';
import 'package:ababilx/features/attachments/auto_download/auto_download_settings.dart';
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
    bool auto(
      ChatMessageAttachment a, {
      AutoDownloadSettings settings = AutoDownloadSettings.defaults,
      NetworkClass network = NetworkClass.wifi,
    }) => shouldAutoDownload(a, settings: settings, network: network);

    test('classifies an attachment by the knob that governs it', () {
      expect(autoDownloadMediaOf(attachment()), AutoDownloadMedia.photos);
      expect(
        autoDownloadMediaOf(attachment(name: 'voice.m4a', type: 'audio/mp4')),
        AutoDownloadMedia.audio,
      );
      expect(
        autoDownloadMediaOf(attachment(name: 'clip.mp4', type: 'video/mp4')),
        AutoDownloadMedia.video,
      );
      // Everything unrecognised is a document, so no attachment falls through
      // the four switches with nothing governing it.
      expect(
        autoDownloadMediaOf(attachment(name: 'deck.pptx', type: '')),
        AutoDownloadMedia.documents,
      );
    });

    test('defaults keep photos and voice notes automatic', () {
      expect(auto(attachment()), isTrue);
      expect(auto(attachment(name: 'voice.m4a', type: 'audio/mp4')), isTrue);
      expect(auto(attachment(name: 'clip.mp4', type: 'video/mp4')), isFalse);
    });

    test('roaming is off by default even for photos', () {
      expect(auto(attachment(), network: NetworkClass.cellular), isTrue);
      expect(auto(attachment(), network: NetworkClass.roaming), isFalse);
    });

    test('nothing starts with no route out', () {
      final everything = AutoDownloadSettings.defaults.withNetworks(
        AutoDownloadMedia.photos,
        AutoDownloadNetwork.values.toSet(),
      );
      expect(
        auto(attachment(), settings: everything, network: NetworkClass.offline),
        isFalse,
      );
    });

    test('the user can turn video on for one network only', () {
      final wifiVideo = AutoDownloadSettings.defaults.withNetworks(
        AutoDownloadMedia.video,
        {AutoDownloadNetwork.wifi},
      );
      final clip = attachment(name: 'clip.mp4', type: 'video/mp4');
      expect(auto(clip, settings: wifiVideo), isTrue);
      expect(
        auto(clip, settings: wifiVideo, network: NetworkClass.cellular),
        isFalse,
      );
    });

    test('the size ceiling and availability are not the user to decide', () {
      final everything = AutoDownloadSettings({
        for (final media in AutoDownloadMedia.values) media: 7,
      });
      expect(auto(attachment(locked: true), settings: everything), isFalse);
      expect(
        auto(attachment(bytes: 6 * 1024 * 1024), settings: everything),
        isFalse,
      );
    });

    test('describe never shows an empty value', () {
      expect(
        AutoDownloadSettings.defaults.describe(AutoDownloadMedia.video),
        'Never',
      );
      expect(
        AutoDownloadSettings.defaults.describe(AutoDownloadMedia.photos),
        'Wi-Fi, Cellular',
      );
      expect(
        AutoDownloadSettings.defaults
            .withNetworks(
              AutoDownloadMedia.photos,
              AutoDownloadNetwork.values.toSet(),
            )
            .describe(AutoDownloadMedia.photos),
        'Always',
      );
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
