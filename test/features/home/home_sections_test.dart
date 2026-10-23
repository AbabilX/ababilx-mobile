import 'package:ababilx/features/home/home_sections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

List<String> ids(List<HomeSection> s) => [for (final x in s) x.id];

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('default is the shipped layout', () {
    expect(ids(const HomeSectionPrefs().shown), [
      'focus',
      'pinned',
      'nearby',
      'callers',
      'recent',
    ]);
  });

  test('move and hide apply to what Home draws', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(homeSectionsProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await n.move(4, 0);
    await n.setShown('nearby', false);
    final prefs = c.read(homeSectionsProvider);
    expect(ids(prefs.shown), ['recent', 'focus', 'pinned', 'callers']);
    expect(ids(prefs.ordered).length, 5);
  });

  test('a block the saved order lacks keeps its default place after', () {
    const prefs = HomeSectionPrefs(order: ['recent', 'focus']);
    expect(ids(prefs.ordered), [
      'recent',
      'focus',
      'pinned',
      'nearby',
      'callers',
    ]);
  });
}
