import 'package:ababilx/features/messages/history-transfer/history_transfer_one_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live only when the server lists live version 1', () {
    expect(liveSupported({'live_versions': [1]}), isTrue);
    expect(liveSupported({'versions': [1, 2]}), isFalse);
    expect(liveSupported({'live_versions': [2]}), isFalse);
  });
}
