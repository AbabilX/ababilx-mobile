import 'package:ababilx/features/messages/chat-timeline/voice_bubble_footer.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/shared/widgets/voice_flat_layout.dart';
import 'package:ababilx/shared/widgets/voice_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _voice = ChatMessageAttachment(
  id: 'a1',
  messageId: 'm1',
  fileName: 'voice-message-34s.m4a',
  fileUrl: 'https://cdn.example/voice-1.m4a',
  contentType: 'audio/mp4',
  sizeBytes: 48 * 1024,
  uploadedBy: 'u1',
  createdAt: '2026-10-04T00:00:00.000Z',
);

ChatMessage _message({
  String body = '',
  List<ChatMessageAttachment> attachments = const [_voice],
}) => ChatMessage(
  id: 'm1',
  conversationId: 'c1',
  userId: 'u1',
  body: body,
  createdAt: '2026-10-04T00:00:00.000Z',
  attachments: attachments,
);

void main() {
  test('only a lone voice note takes the footer onto its own line', () {
    expect(isVoiceBubble(_message()), isTrue);
    expect(isVoiceBubble(_message(body: 'listen')), isFalse);
    expect(
      isVoiceBubble(_message(attachments: const [_voice, _voice])),
      isFalse,
    );
    expect(isVoiceBubble(_message(attachments: const [])), isFalse);
  });

  test('a note keeps its shape, and two notes differ', () {
    List<double> bars(int seed) => [
      for (var i = 0; i < 40; i++) voiceBarHeight(seed, i),
    ];
    expect(bars(7), bars(7));
    expect(bars(7), isNot(bars(8)));
    expect(bars(7).every((h) => h >= 0.12 && h <= 1), isTrue);
  });

  testWidgets('clock at the start of the line, time and ticks at its end', (
    tester,
  ) async {
    var toggled = 0;
    double? sought;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: VoiceRowFrame.width,
              child: VoiceFlatLayout(
                playing: false,
                progress: 0.4,
                clock: '0:34',
                seed: 'a',
                onToggle: () => toggled++,
                onSeek: (at) => sought = at,
                trailing: const Text('12:05'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(VoiceFlatLayout)).height,
      VoiceRowFrame.height,
    );

    final clock = tester.getRect(find.text('0:34'));
    final time = tester.getRect(find.text('12:05'));
    final wave = tester.getRect(find.byType(VoiceWaveform));
    expect(clock.left, closeTo(wave.left, 0.5));
    expect(time.right, closeTo(wave.right, 0.5));
    expect(clock.top, greaterThan(wave.bottom - 0.5));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(toggled, 1);

    await tester.tapAt(Offset(wave.left + wave.width * 0.75, wave.center.dy));
    expect(sought, closeTo(0.75, 0.02));
  });

  testWidgets('a large system font shortens the bars, never overflows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: VoiceRowFrame.width,
                child: VoiceFlatLayout(
                  playing: true,
                  progress: 1,
                  clock: '0:34',
                  seed: 'a',
                  onToggle: () {},
                  trailing: const Text('12:05'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
