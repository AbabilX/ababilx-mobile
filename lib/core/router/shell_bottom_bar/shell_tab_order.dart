import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell_tabs.dart';

const _key = 'shell_tab_order_v1';

/// [tabs] in the order the user dragged them to; a tab the saved order has not
/// heard of keeps its default place after the known ones.
List<ShellTab> applyTabOrder(List<ShellTab> tabs, List<String> order) {
  int rank(ShellTab t) {
    final i = order.indexOf(t.route);
    return i < 0 ? order.length + tabs.indexOf(t) : i;
  }

  return [...tabs]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// Device-local, like the chat-list pill order: how someone arranges their own
/// bar is not something the server needs.
class ShellTabOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final saved = await SharedPreferencesAsync().getStringList(_key);
      if (saved != null) state = saved;
    } catch (_) {}
  }

  /// Moves the tab at [from] to [to] in the order [shown] is drawn in.
  /// A tab missing from [shown] (Home switched off) keeps its saved place,
  /// so switching it back on puts it where it was.
  Future<void> move(List<ShellTab> shown, int from, int to) async {
    if (from == to || from < 0 || to < 0) return;
    if (from >= shown.length || to >= shown.length) return;
    final next = [for (final t in shown) t.route];
    next.insert(to, next.removeAt(from));
    final full = applyTabOrder(homeShellTabs, state);
    for (var i = 0; i < full.length; i++) {
      final route = full[i].route;
      if (!next.contains(route)) next.insert(i.clamp(0, next.length), route);
    }
    state = next;
    try {
      await SharedPreferencesAsync().setStringList(_key, next);
    } catch (_) {}
  }
}

final shellTabOrderProvider =
    NotifierProvider<ShellTabOrderNotifier, List<String>>(
      ShellTabOrderNotifier.new,
    );
