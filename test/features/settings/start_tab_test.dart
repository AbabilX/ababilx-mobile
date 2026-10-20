import 'package:ababilx/features/settings/start-tab/start_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a tab the bar has is honoured, anything else is Messages', () {
    expect(StartTab.sanitize('/home'), '/home');
    expect(StartTab.sanitize('/calls'), '/calls');
    expect(StartTab.sanitize('/messages'), '/messages');
    expect(StartTab.sanitize('/wall'), '/messages');
    expect(StartTab.sanitize(null), '/messages');
  });
}
