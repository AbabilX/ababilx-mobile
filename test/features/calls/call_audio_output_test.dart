import 'package:ababilx/features/calls/audio/call_audio_output.dart';
import 'package:ababilx/features/calls/widgets/call_audio_output_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

CallAudioDevices _devices(
  String active,
  int activeId,
  List<(String, int)> rows,
) => CallAudioDevices.fromMap({
  'active': active,
  'activeId': activeId,
  'options': [
    for (final (type, id) in rows)
      {'type': type, 'id': id, 'name': '', 'detail': ''},
  ],
});

void main() {
  group('Signal picker rule (SHOW_PICKER_THRESHOLD = 3)', () {
    test('earpiece + speaker cycles, no picker', () {
      final d = _devices('handset', 1, [('handset', 1), ('speaker', 2)]);
      expect(d.willDisplayPicker, isFalse);
      expect(d.next?.output, CallAudioOutput.speaker);
    });

    test('speaker cycles back to the earpiece', () {
      final d = _devices('speaker', 2, [('handset', 1), ('speaker', 2)]);
      expect(d.next?.output, CallAudioOutput.handset);
    });

    test('a Bluetooth headset makes three: the picker opens', () {
      final d = _devices('bluetooth', 7, [
        ('handset', 1),
        ('speaker', 2),
        ('bluetooth', 7),
      ]);
      expect(d.willDisplayPicker, isTrue);
    });

    test(
      'wired headset replaces the earpiece: no earpiece means the picker',
      () {
        final d = _devices('wired', 5, [('speaker', 2), ('wired', 5)]);
        expect(d.willDisplayPicker, isTrue);
      },
    );

    test('unknown current device cycles by kind', () {
      final d = _devices('handset', -1, [('handset', 1), ('speaker', 2)]);
      expect(d.next?.output, CallAudioOutput.speaker);
    });

    test('nothing reported yet falls back to the speaker switch', () {
      expect(CallAudioDevices.empty.known, isFalse);
      expect(CallAudioDevices.empty.willDisplayPicker, isFalse);
      expect(CallAudioDevices.empty.next, isNull);
    });
  });

  group('button face', () {
    test('two-way switch on the earpiece shows the speaker, unselected', () {
      final face = CallAudioButtonFace.of(
        _devices('handset', 1, [('handset', 1), ('speaker', 2)]),
        speaker: false,
      );
      expect(face.output, CallAudioOutput.speaker);
      expect(face.selected, isFalse);
      expect(face.dropdown, isFalse);
    });

    test('on the speaker it is selected', () {
      final face = CallAudioButtonFace.of(
        _devices('speaker', 2, [('handset', 1), ('speaker', 2)]),
        speaker: true,
      );
      expect(face.selected, isTrue);
    });

    test('with a headset it shows the headset and a drop-down', () {
      final face = CallAudioButtonFace.of(
        _devices('bluetooth', 7, [
          ('handset', 1),
          ('speaker', 2),
          ('bluetooth', 7),
        ]),
        speaker: false,
      );
      expect(face.output, CallAudioOutput.bluetooth);
      expect(face.dropdown, isTrue);
    });
  });
}
