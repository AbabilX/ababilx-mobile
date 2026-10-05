import 'package:ababilx/core/router/shell_bottom_bar/shell_tab_order.dart';
import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> routes(List<ShellTab> t) => [for (final x in t) x.route];

  test('no saved order keeps the default', () {
    expect(routes(applyTabOrder(homeShellTabs, const [])), [
      '/messages',
      '/calls',
    ]);
  });

  test('saved order wins; an unknown tab goes last', () {
    expect(routes(applyTabOrder(homeShellTabs, ['/calls'])), [
      '/calls',
      '/messages',
    ]);
  });
}
