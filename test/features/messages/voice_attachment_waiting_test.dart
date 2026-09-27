import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/messages/chat-timeline/voice_attachment_waiting.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _voice = ChatMessageAttachment(
  id: 'a1',
  messageId: 'm1',
  fileName: 'voice-1.m4a',
  fileUrl: 'https://cdn.example/voice-1.m4a',
  contentType: 'audio/mp4',
  sizeBytes: 48 * 1024,
  uploadedBy: 'u1',
  createdAt: '2026-09-27T00:00:00.000Z',
);

AttachmentHandle _handle(AttachmentTransferState state) => AttachmentHandle(
  urlKey: 'k',
  remoteUrl: _voice.fileUrl,
  state: state,
  receivedBytes: 12 * 1024,
  totalBytes: 48 * 1024,
);

void main() {
  // The timeline reserves 220x40 for a voice note; the old gate badge (44dp
  // ring over a "Cancel" label) overflowed it for as long as the download ran.
  for (final state in [
    null,
    AttachmentTransferState.absent,
    AttachmentTransferState.queued,
    AttachmentTransferState.downloading,
    AttachmentTransferState.failed,
    AttachmentTransferState.permanentlyFailed,
  ]) {
    testWidgets('waiting voice note fits its 40dp row: ${state?.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  height: 40,
                  child: VoiceAttachmentWaiting(
                    attachment: _voice,
                    handle: state == null ? null : _handle(state),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
