import 'package:flutter/widgets.dart';

/// Whether this page of a [SwipeTabPager] is the tab the route names.
///
/// The pager keeps its pages alive, so a page can no longer treat initState as
/// "opened" and dispose as "left" — both happen once. A page that does
/// something per visit reads this instead.
class SwipeTabActive extends InheritedWidget {
  const SwipeTabActive({super.key, required this.active, required super.child});

  final bool active;

  /// True outside a pager, so a screen shown on its own behaves as visible.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SwipeTabActive>()?.active ??
      true;

  /// [of] without subscribing, for async code outside build.
  static bool read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SwipeTabActive>()?.active ?? true;

  @override
  bool updateShouldNotify(SwipeTabActive oldWidget) =>
      oldWidget.active != active;
}

/// Turns [SwipeTabActive] changes into shown / hidden calls. Neither runs for
/// the first build — that is still initState's job.
///
/// Both are called from didChangeDependencies, right before build: set fields
/// directly, and defer any provider write to after the frame.
mixin SwipeTabVisits<T extends StatefulWidget> on State<T> {
  bool? _tabActive;

  /// This page is on screen as its tab (true before the first build).
  bool get tabActive => _tabActive ?? true;

  void onTabShown() {}
  void onTabHidden() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = SwipeTabActive.of(context);
    final was = _tabActive;
    if (was == active) return;
    _tabActive = active;
    if (was == null) return;
    active ? onTabShown() : onTabHidden();
  }
}
