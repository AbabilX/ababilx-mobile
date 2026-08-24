import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('visibleShellTabs', () {
    test('team-less account gets the two-tab Signal shape', () {
      final tabs = visibleShellTabs(hasTeam: false, showCrm: false);
      expect(tabs.map((t) => t.route), ['/messages', '/calls']);
    });

    test('workspace features appear only once a team exists', () {
      final tabs = visibleShellTabs(hasTeam: true, showCrm: false);
      expect(tabs.map((t) => t.route), [
        '/messages',
        '/calls',
        '/wall',
        '/board',
      ]);
    });

    test('CRM needs both a team and access', () {
      expect(
        visibleShellTabs(hasTeam: true, showCrm: true).map((t) => t.route),
        ['/messages', '/calls', '/wall', '/crm', '/board'],
      );
      // CRM access without a team never renders a lone CRM tab.
      expect(
        visibleShellTabs(hasTeam: false, showCrm: true).map((t) => t.route),
        ['/messages', '/calls'],
      );
    });

    test('unread badge rides on Messages alone', () {
      final tabs = visibleShellTabs(hasTeam: true, showCrm: true);
      expect(tabs.where((t) => t.showsUnread).map((t) => t.route), [
        '/messages',
      ]);
    });
  });

  group('shellTabIndex', () {
    final full = visibleShellTabs(hasTeam: true, showCrm: true);
    final minimal = visibleShellTabs(hasTeam: false, showCrm: false);

    test('sub-routes select their owning tab', () {
      expect(shellTabIndex(full, '/crm/contacts'), 3);
      expect(shellTabIndex(full, '/board/abc/tasks/1'), 4);
      expect(shellTabIndex(full, '/calls'), 1);
    });

    test('index follows the visible list, not a fixed position', () {
      // Board is 4th with CRM present, 3rd without — the old hardcoded
      // `showCrm ? 3 : 2` arithmetic is what this replaces.
      final noCrm = visibleShellTabs(hasTeam: true, showCrm: false);
      expect(shellTabIndex(full, '/board'), 4);
      expect(shellTabIndex(noCrm, '/board'), 3);
    });

    test('a route whose tab is hidden falls back to Messages', () {
      expect(shellTabIndex(minimal, '/board'), 0);
      expect(shellTabIndex(minimal, '/crm/leads'), 0);
      expect(shellTabIndex(minimal, '/profile'), 0);
    });
  });
}
