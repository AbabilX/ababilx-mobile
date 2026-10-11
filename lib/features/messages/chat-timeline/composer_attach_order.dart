import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'composer_attach_order_v1';

/// True while a chip is held for rearranging; the chat behind blurs.
final ValueNotifier<bool> attachReordering = ValueNotifier(false);

/// The destinations under the media rail, in their default order: what is
/// reached for every day first, the occasional ones after.
enum AttachDestination { gallery, camera, file, task, snippet, ghost, khaam }

/// The chips in the order the user dragged them to. One the saved order has
/// not heard of (a new one, or one this chat only offers sometimes) goes
/// last, in its default place.
List<AttachDestination> applyAttachOrder(
  List<AttachDestination> shown,
  List<String> order,
) {
  int rank(AttachDestination d) {
    final i = order.indexOf(d.name);
    return i < 0 ? order.length + d.index : i;
  }

  return [...shown]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// Device-local, like the chat list's filter pills: how someone arranges
/// their own chips is not something the server needs.
class AttachOrderNotifier extends Notifier<List<String>> {
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

  Future<void> save(List<AttachDestination> shown) async {
    // Chips this chat does not offer keep their old place at the end.
    final names = [for (final d in shown) d.name];
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

final attachOrderProvider = NotifierProvider<AttachOrderNotifier, List<String>>(
  AttachOrderNotifier.new,
);
