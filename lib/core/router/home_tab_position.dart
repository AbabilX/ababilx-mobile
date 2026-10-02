import 'package:flutter/widgets.dart';

/// Where the home tab pager sits, in pages (0.0 = first tab, 1.0 = second,
/// 0.5 = halfway through a swipe). Null until the pager has reported.
///
/// The bottom bar reads this to slide its chosen-tab background with the
/// finger / animation instead of snapping when the route finally changes.
final ValueNotifier<double?> homeTabPosition = ValueNotifier<double?>(null);

/// The pager's controller, so a drag on the bottom bar can move the pages.
/// Held, never listened to.
PageController? homeTabController;
