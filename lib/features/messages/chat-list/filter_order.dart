import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat_list_filters.dart';

const _key = 'chat_filter_order_v1';

/// The pills in the order the user dragged them to. All always stays first;
/// a pill the saved order has not heard of (a new one, or one that only
/// appears sometimes) goes last in its default place.
List<ChatListFilter> applyFilterOrder(
  List<ChatListFilter> filters,
  List<String> order,
) {
  if (filters.isEmpty) return filters;
  int rank(ChatListFilter f) {
    final i = order.indexOf(f.name);
    return i < 0 ? order.length + f.index : i;
  }

  final rest = [
    for (final f in filters)
      if (f != ChatListFilter.all) f,
  ]..sort((a, b) => rank(a).compareTo(rank(b)));
  return [
    if (filters.contains(ChatListFilter.all)) ChatListFilter.all,
    ...rest,
  ];
}

/// Device-local, like the wallpaper: how someone arranges their own pills is
/// not something the server needs.
class FilterOrderNotifier extends Notifier<List<String>> {
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

  Future<void> save(List<ChatListFilter> shown) async {
    // Pills not on screen right now keep their old place at the end.
    final names = [for (final f in shown) f.name];
    state = [
      ...names,
      for (final n in state)
        if (!names.contains(n)) n,
    ];
    try {
      await SharedPreferencesAsync().setStringList(_key, state);
    } catch (_) {}
  }
}

final filterOrderProvider = NotifierProvider<FilterOrderNotifier, List<String>>(
  FilterOrderNotifier.new,
);
