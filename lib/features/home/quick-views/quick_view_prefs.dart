import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quick_views.dart';

const _orderKey = 'home_quick_view_order_v1';

/// How this person arranged Home's cards (hold and drag). Device-local, like
/// the tab and filter-pill orders: nobody else needs to know.
class QuickViewPrefs {
  const QuickViewPrefs({this.order = const []});

  final List<String> order;

  /// Every card in its arranged order.
  List<HomeQuickView> get arranged => orderQuickViews(order);
}

class QuickViewPrefsNotifier extends Notifier<QuickViewPrefs> {
  @override
  QuickViewPrefs build() {
    _load();
    return const QuickViewPrefs();
  }

  Future<void> _load() async {
    try {
      final order = await SharedPreferencesAsync().getStringList(_orderKey);
      if (order != null) state = QuickViewPrefs(order: order);
    } catch (_) {}
  }

  /// [to] is already adjusted for the removed slot (`onReorderItem`).
  Future<void> move(int from, int to) async {
    final next = [for (final v in state.arranged) v.name];
    if (from < 0 || from >= next.length || from == to) return;
    next.insert(to.clamp(0, next.length - 1), next.removeAt(from));
    state = QuickViewPrefs(order: next);
    try {
      await SharedPreferencesAsync().setStringList(_orderKey, next);
    } catch (_) {}
  }
}

final quickViewPrefsProvider =
    NotifierProvider<QuickViewPrefsNotifier, QuickViewPrefs>(
      QuickViewPrefsNotifier.new,
    );
