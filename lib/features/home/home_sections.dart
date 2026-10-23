import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One block of the Home tab. The id is what is stored; the label key names
/// it on Settings → Appearance → Tabs.
class HomeSection {
  const HomeSection(this.id, this.labelKey);

  final String id;
  final String labelKey;
}

/// Home's blocks in their default order (the layout Home shipped with).
const homeSections = [
  HomeSection('focus', 'home_catch_up'),
  HomeSection('pinned', 'home_pinned'),
  HomeSection('nearby', 'home_nearby'),
  HomeSection('callers', 'home_talk_again'),
  HomeSection('recent', 'home_recent_chats'),
];

/// Order + which blocks are off. Device-local, like the tab order.
class HomeSectionPrefs {
  const HomeSectionPrefs({this.order = const [], this.hidden = const {}});

  final List<String> order;
  final Set<String> hidden;

  /// Every block, in the user's order; a block the saved order does not know
  /// keeps its default place after the known ones.
  List<HomeSection> get ordered {
    int rank(HomeSection s) {
      final i = order.indexOf(s.id);
      return i < 0 ? order.length + homeSections.indexOf(s) : i;
    }

    return [...homeSections]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// What Home draws, top to bottom.
  List<HomeSection> get shown => [
    for (final s in ordered)
      if (!hidden.contains(s.id)) s,
  ];
}

class HomeSectionsNotifier extends Notifier<HomeSectionPrefs> {
  static const _orderKey = 'home_sections_order_v1';
  static const _hiddenKey = 'home_sections_hidden_v1';

  @override
  HomeSectionPrefs build() {
    _load();
    return const HomeSectionPrefs();
  }

  Future<void> _load() async {
    try {
      final prefs = SharedPreferencesAsync();
      final order = await prefs.getStringList(_orderKey);
      final hidden = await prefs.getStringList(_hiddenKey);
      state = HomeSectionPrefs(order: order ?? const [], hidden: {...?hidden});
    } catch (_) {}
  }

  /// Moves the block at [from] to [to] in [HomeSectionPrefs.ordered].
  Future<void> move(int from, int to) async {
    final next = [for (final s in state.ordered) s.id];
    if (from == to || from < 0 || to < 0) return;
    if (from >= next.length || to >= next.length) return;
    next.insert(to, next.removeAt(from));
    state = HomeSectionPrefs(order: next, hidden: state.hidden);
    try {
      await SharedPreferencesAsync().setStringList(_orderKey, next);
    } catch (_) {}
  }

  Future<void> setShown(String id, bool shown) async {
    final hidden = {...state.hidden};
    shown ? hidden.remove(id) : hidden.add(id);
    state = HomeSectionPrefs(order: state.order, hidden: hidden);
    try {
      await SharedPreferencesAsync().setStringList(_hiddenKey, [...hidden]);
    } catch (_) {}
  }
}

final homeSectionsProvider =
    NotifierProvider<HomeSectionsNotifier, HomeSectionPrefs>(
      HomeSectionsNotifier.new,
    );
