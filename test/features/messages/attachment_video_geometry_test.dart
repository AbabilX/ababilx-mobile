import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test adapter for the video_player plugin's platform boundary.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/providers/attachment_providers.dart';
import 'package:ababilx/features/messages/chat-timeline/attachment_video_tile.dart';
import 'package:ababilx/features/messages/chat-timeline/attachment_file_row.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/shared/widgets/preview_icon.dart';

const attachment = ChatMessageAttachment(
  id: 'video',
  messageId: 'm',
  fileName: 'clip.mp4',
  fileUrl: 'https://example.invalid/video',
  contentType: 'video/mp4',
  sizeBytes: 100,
  uploadedBy: 'u',
  createdAt: '',
);
const ready = AttachmentHandle(
  urlKey: 'video',
  remoteUrl: 'https://example.invalid/video',
  state: AttachmentTransferState.ready,
  localPath: '/tmp/test-video.mp4',
);

void main() {
  for (final size in [
    const Size(1920, 1080),
    const Size(1080, 1920),
    Size.zero,
  ]) {
    testWidgets('video frame stays fixed through loading and metadata $size', (
      tester,
    ) async {
      final previous = VideoPlayerPlatform.instance;
      final platform = _VideoPlatform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() {
        VideoPlayerPlatform.instance = previous;
      });
      final stream = StreamController<AttachmentHandle>.broadcast();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attachmentHandleProvider(
              attachment,
            ).overrideWith((ref) => stream.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: AttachmentVideoTile(attachment: attachment)),
            ),
          ),
        ),
      );
      final tile = find.byType(AttachmentVideoTile);
      final before = tester.getRect(tile);
      stream.add(ready);
      await tester.pump();
      await tester.pump();
      expect(tester.getRect(tile), before);
      if (size == Size.zero) {
        platform.events.addError(
          PlatformException(
            code: 'decode_failed',
            message: 'Fixture decode failure',
          ),
        );
      } else {
        platform.events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 5),
            size: size,
          ),
        );
      }
      await tester.pump();
      await tester.pump();
      expect(tester.getRect(tile), before);
      expect(
        size == Size.zero
            ? find.byWidgetPredicate(
                (w) =>
                    w is PreviewIcon && identical(w.icon, PreviewIcons.videoOff),
              )
            : find.byType(AspectRatio),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await stream.close();
      await platform.events.close();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('file row keeps its loading height when open icon arrives', (
    tester,
  ) async {
    final stream = StreamController<AttachmentHandle>.broadcast();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentHandleProvider(
            attachment,
          ).overrideWith((ref) => stream.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: AttachmentFileRow(attachment: attachment),
              ),
            ),
          ),
        ),
      ),
    );
    final row = find.byType(AttachmentFileRow);
    final before = tester.getRect(row);
    stream.add(ready);
    await tester.pump();
    expect(tester.getRect(row), before);
    expect(
      find.byWidgetPredicate(
        (w) => w is PreviewIcon && identical(w.icon, PreviewIcons.chevron),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await stream.close();
  });
}

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>.broadcast();
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}
