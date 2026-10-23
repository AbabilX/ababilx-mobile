import 'package:ababilx/core/router/shell_bottom_bar/shell_tab_order.dart';
import 'package:ababilx/core/router/shell_bottom_bar/shell_tabs.dart';
import 'package:ababilx/features/settings/appearance/home_tab_setting.dart';
import 'package:ababilx/features/settings/start-tab/start_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => HomeTabSetting.save(false));

  test('Home is off until turned on', () async {
    await HomeTabSetting.preload();
    expect(HomeTabSetting.shown, isFalse);
  });

  test(
    'only a tab the bar has is honoured, anything else is Messages',
    () async {
      await HomeTabSetting.save(true);
      expect(StartTab.sanitize('/home'), '/home');
      expect(StartTab.sanitize('/calls'), '/calls');
      expect(StartTab.sanitize('/messages'), '/messages');
      expect(StartTab.sanitize('/wall'), '/messages');
      expect(StartTab.sanitize(null), '/messages');
    },
  );

  test(
    'Home hidden: launch falls back to Messages, choice comes back',
    () async {
      await StartTab.save('/home');
      await HomeTabSetting.save(false);
      expect(StartTab.route, '/messages');
      await HomeTabSetting.save(true);
      expect(StartTab.route, '/home');
    },
  );

  test('bar without Home drops only Home', () {
    expect(
      [for (final t in visibleShellTabs(homeShown: false)) t.route],
      ['/messages', '/calls'],
    );
    expect(visibleShellTabs(homeShown: true), homeShellTabs);
  });

  test('reordering while Home is hidden keeps its saved place', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final order = container.read(shellTabOrderProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final shown = visibleShellTabs(homeShown: false);
    await order.move(shown, 0, 1);
    expect(container.read(shellTabOrderProvider), [
      '/home',
      '/calls',
      '/messages',
    ]);
  });
}
