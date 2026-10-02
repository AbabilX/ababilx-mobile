import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home bar is the two-tab Signal shape', () {
    expect(homeShellTabs.map((t) => t.route), ['/messages', '/calls']);
  });

  test('unread badge rides on Messages alone', () {
    expect(homeShellTabs.where((t) => t.showsUnread).map((t) => t.route), [
      '/messages',
    ]);
  });

  group('shellTabIndex', () {
    test('sub-routes select their owning tab', () {
      expect(shellTabIndex(homeShellTabs, '/calls'), 1);
      expect(shellTabIndex(homeShellTabs, '/messages'), 0);
    });

    test('an unknown route falls back to Messages', () {
      expect(shellTabIndex(homeShellTabs, '/crm/leads'), 0);
      expect(shellTabIndex(homeShellTabs, '/profile'), 0);
    });
  });
}
