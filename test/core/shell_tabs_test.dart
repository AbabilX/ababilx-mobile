import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home bar is Home, Messages, Spaces, Calls', () {
    expect(homeShellTabs.map((t) => t.route), [
      '/home',
      '/messages',
      '/spaces',
      '/calls',
    ]);
  });

  test('unread badge rides on Messages alone', () {
    expect(homeShellTabs.where((t) => t.showsUnread).map((t) => t.route), [
      '/messages',
    ]);
  });

  group('shellTabIndex', () {
    test('sub-routes select their owning tab', () {
      expect(shellTabIndex(homeShellTabs, '/home'), 0);
      expect(shellTabIndex(homeShellTabs, '/messages'), 1);
      expect(shellTabIndex(homeShellTabs, '/spaces'), 2);
      expect(shellTabIndex(homeShellTabs, '/calls'), 3);
    });

    test('an unknown route falls back to Messages', () {
      expect(shellTabIndex(homeShellTabs, '/crm/leads'), 1);
      expect(shellTabIndex(homeShellTabs, '/profile'), 1);
    });
  });
}
