import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tap on the home-bar tab that is already showing.
///
/// [serial] makes two taps on the same tab two different values, so a
/// listener fires for each. [route] says which tab: the Chats/Talks pager
/// keeps both pages alive, so each page ignores the other's taps.
class TabReselect {
  const TabReselect(this.route, this.serial);

  final String route;
  final int serial;
}

final tabReselectProvider = StateProvider<TabReselect?>((ref) => null);

int _serial = 0;

void signalTabReselect(WidgetRef ref, String route) {
  ref.read(tabReselectProvider.notifier).state = TabReselect(route, ++_serial);
}
