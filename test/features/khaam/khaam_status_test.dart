import 'package:ababilx/features/khaam/data/khaam_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ours is always sent; theirs is unopened until opened', () {
    expect(khaamStatus(isOwn: true, opened: false), KhaamStatus.sent);
    expect(khaamStatus(isOwn: true, opened: true), KhaamStatus.sent);
    expect(khaamStatus(isOwn: false, opened: false), KhaamStatus.unopened);
    expect(khaamStatus(isOwn: false, opened: true), KhaamStatus.opened);
  });
}
