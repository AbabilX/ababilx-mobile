import 'package:ababilx/features/jpack/data/jpack_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ours is always sent; theirs is unopened until opened', () {
    expect(jpackStatus(isOwn: true, opened: false), JPackStatus.sent);
    expect(jpackStatus(isOwn: true, opened: true), JPackStatus.sent);
    expect(jpackStatus(isOwn: false, opened: false), JPackStatus.unopened);
    expect(jpackStatus(isOwn: false, opened: true), JPackStatus.opened);
  });
}
