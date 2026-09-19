import 'package:ababilx/features/calls/webrtc/voice_audio_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio recovery can be detected across repeated network outages', () {
    final progress = VoiceAudioProgress();
    expect(progress.update({'audio': 100}), isFalse);
    expect(progress.update({'audio': 100}), isFalse);
    expect(progress.update({'audio': 110}), isTrue);
    expect(progress.update({'audio': 110}), isFalse);
    expect(progress.update({'audio': 120}), isTrue);
  });

  test('new SSRCs and reset counters need fresh packet evidence', () {
    final progress = VoiceAudioProgress();
    expect(progress.update({'old': 100}), isFalse);
    expect(progress.update({'new': 200}), isFalse);
    expect(progress.update({'new': 201}), isTrue);
    expect(progress.update({'new': 0}), isFalse);
    expect(progress.update({'new': 1}), isTrue);
    expect(progress.update({}), isFalse);
    expect(progress.update({'new': 500}), isFalse);
  });
}
