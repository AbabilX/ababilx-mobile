import 'package:ababilx/features/calls/webrtc/voice_media_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class _Stream extends Fake implements MediaStream {
  _Stream(this.id);

  @override
  final String id;
}

void main() {
  test('routes by the ids the peer sent', () {
    final map = VoiceMediaMap()
      ..streams['cam'] = _Stream('cam')
      ..streams['scr'] = _Stream('scr')
      ..apply({'camera_stream': 'cam', 'screen_stream': 'scr'});
    expect(map.camera?.id, 'cam');
    expect(map.screen?.id, 'scr');
  });

  test('awaits a stream the peer named and has not sent yet', () {
    final map = VoiceMediaMap()
      ..streams['cam'] = _Stream('cam')
      ..apply({'camera_stream': '', 'screen_stream': 'scr'});
    expect(map.awaiting, isTrue);
    map.streams['scr'] = _Stream('scr');
    expect(map.awaiting, isFalse);
  });

  test('a camera already held is not awaited again', () {
    final map = VoiceMediaMap()
      ..streams['cam'] = _Stream('cam')
      ..apply({'camera_stream': 'cam', 'screen_stream': ''});
    expect(map.awaiting, isFalse);
  });

  test('nothing named, nothing awaited', () {
    final map = VoiceMediaMap()
      ..apply({'camera_stream': '', 'screen_stream': ''});
    expect(map.awaiting, isFalse);
  });
}
