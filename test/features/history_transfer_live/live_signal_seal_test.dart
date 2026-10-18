import 'package:ababilx/features/messages/history-transfer/live/live_signal_seal.dart';
import 'package:flutter_test/flutter_test.dart';

// Pinned by web's src/lib/history/live/wire.test.mjs: key 01..20, zero nonce.
const _sealed = 'vVuvYM0wN989RYJqEkKI1ukE7XYdjq5bTxfYvpK58iLD81JcQkwJpIyy';

void main() {
  final key = List.generate(32, (i) => i + 1);

  test('seals exactly as the web opens', () async {
    final signal = await LiveSignalSeal.seal(
      key,
      'L1',
      'source',
      'offer',
      {'type': 'offer', 'sdp': 'x'},
      nonce: List.filled(12, 0),
    );
    expect(signal, {'kind': 'offer', 'nonce': 'AAAAAAAAAAAAAAAA', 'sealed': _sealed});
  });

  test('opens only for the sender it names', () async {
    final signal = {'kind': 'offer', 'nonce': 'AAAAAAAAAAAAAAAA', 'sealed': _sealed};
    expect(await LiveSignalSeal.open(key, 'L1', 'source', signal), {'type': 'offer', 'sdp': 'x'});
    expect(LiveSignalSeal.open(key, 'L1', 'destination', signal), throwsA(anything));
  });
}
