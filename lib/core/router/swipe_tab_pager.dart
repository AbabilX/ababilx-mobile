import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_tab_position.dart';
import 'swipe_tab_active.dart';

/// Neighbouring shell tabs as one horizontal pager: the page follows the
/// finger and lands on the next tab — WhatsApp's swipe between its tabs.
///
/// Every route in [routes] must build this widget inside a page with ONE
/// shared key (see `home_tab_pager.dart`). Going from one of those routes to
/// another then UPDATES that page instead of replacing it, so the pager
/// survives the route change and only moves. The route stays the truth — the
/// bottom bar, back and deep links all read it — and a swipe writes it once
/// the page has settled. Writing it mid-drag, as `onPageChanged` would at the
/// halfway point, rebuilds the shell under the finger.
///
/// Every page is built once and kept alive, so a swipe only moves pixels. A
/// page that did something on open or close (Talks marks missed calls seen)
/// does it on shown / hidden instead — see [SwipeTabVisits].
class SwipeTabPager extends StatefulWidget {
  const SwipeTabPager({
    super.key,
    required this.index,
    required this.routes,
    required this.pages,
  });

  /// Page the current route names.
  final int index;

  /// One route per page, in the order the bottom bar shows them.
  final List<String> routes;
  final List<Widget> pages;

  @override
  State<SwipeTabPager> createState() => _SwipeTabPagerState();
}

class _SwipeTabPagerState extends State<SwipeTabPager> {
  late final PageController _controller = PageController(
    initialPage: widget.index,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_report);
    homeTabController = _controller;
    // After the frame: the bar listens to this and is mid-build right now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) homeTabPosition.value = widget.index.toDouble();
    });
  }

  void _report() {
    final page = _controller.page;
    if (page != null) homeTabPosition.value = page;
  }

  /// Nearest page to where the pager sits now.
  int get _page => (_controller.page ?? widget.index).round();

  @override
  void didUpdateWidget(SwipeTabPager old) {
    super.didUpdateWidget(old);
    // A tab tap, back or a deep link moved the route. After a swipe the route
    // already names the page on screen, so nothing moves.
    if (_controller.hasClients && _page != widget.index) {
      // Slide, never jump: the bar's background slides with it.
      _controller.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _onScroll(ScrollNotification notification) {
    // Depth 0 is the pager itself; the lists inside it report deeper.
    if (notification.depth != 0) return false;
    // Swiping away from a search field takes the keyboard with it.
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (notification is ScrollEndNotification && _page != widget.index) {
      context.go(widget.routes[_page]);
    }
    return false;
  }

  @override
  void dispose() {
    _controller.removeListener(_report);
    if (identical(homeTabController, _controller)) homeTabController = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView(
          controller: _controller,
          // Both tabs are built up front and kept: building one at the
          // moment the finger starts moving is what made the swipe stutter.
          allowImplicitScrolling: true,
          children: [
            for (var i = 0; i < widget.pages.length; i++)
              _KeptPage(
                child: SwipeTabActive(
                  active: i == widget.index,
                  child: widget.pages[i],
                ),
              ),
          ],
        ),
      );
}

class _KeptPage extends StatefulWidget {
  const _KeptPage({required this.child});
  final Widget child;

  @override
  State<_KeptPage> createState() => _KeptPageState();
}

class _KeptPageState extends State<_KeptPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
