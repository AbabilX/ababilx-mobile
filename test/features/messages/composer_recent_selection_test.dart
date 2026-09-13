import 'package:ababilx/features/messages/chat-timeline/composer_recent_selection.dart';
import 'package:ababilx/shared/media/device_gallery.dart';
import 'package:flutter_test/flutter_test.dart';

const _first = DeviceMediaItem(
  uri: 'first-uri',
  name: 'first.jpg',
  mime: 'image/jpeg',
  sizeBytes: 1,
  width: 1,
  height: 1,
  isVideo: false,
  durationMs: 0,
);
const _second = DeviceMediaItem(
  uri: 'second-uri',
  name: 'second.jpg',
  mime: 'image/jpeg',
  sizeBytes: 1,
  width: 1,
  height: 1,
  isVideo: false,
  durationMs: 0,
);

void main() {
  test('quick selections retain tap order', () {
    final first = toggleRecentSelection(const [], _first);
    final second = toggleRecentSelection(first, _second);

    expect(second, const [_first, _second]);
  });

  test('tapping a selected recent removes it', () {
    final result = toggleRecentSelection(const [_first, _second], _first);

    expect(result, const [_second]);
  });
}
