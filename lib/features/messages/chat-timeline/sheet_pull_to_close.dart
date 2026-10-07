import 'package:flutter/material.dart';

/// Closes the sheet when its list is pulled down past its oldest row.
///
/// A timeline is a reversed list, so it swallows every vertical drag and the
/// sheet's own drag-to-dismiss never sees one. Pulling down while the list has
/// nothing older to show is the overscroll reported here.
class SheetPullToClose extends StatefulWidget {
  const SheetPullToClose({super.key, required this.child});
  final Widget child;

  @override
  State<SheetPullToClose> createState() => _SheetPullToCloseState();
}

class _SheetPullToCloseState extends State<SheetPullToClose> {
  static const _threshold = 72.0;
  double _pulled = 0;
  bool _closed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollEndNotification || n is ScrollUpdateNotification) {
      _pulled = 0;
    } else if (n is OverscrollNotification) {
      final dy = n.dragDetails?.delta.dy ?? 0;
      if (dy <= 0) {
        _pulled = 0;
        return false;
      }
      _pulled += dy;
      if (_pulled >= _threshold && !_closed) {
        _closed = true;
        Navigator.of(context).maybePop();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}
