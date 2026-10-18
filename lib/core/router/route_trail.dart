import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'router_path.dart';

/// The last route changes, printed beside a framework error in debug and
/// profile builds (`[RouteTrail]` in logcat).
///
/// A navigator error is decided by the order and spacing of navigations a
/// few hundred milliseconds apart — two `go`s inside one route animation is
/// enough to build the chat list's navigator twice — and the error itself
/// names none of them. Off in release: nothing is recorded there.
abstract final class RouteTrail {
  static const _size = 16;
  static final _entries = <String>[];
  static bool _hooked = false;

  static void attach(GoRouter router) {
    if (kReleaseMode) return;
    var last = '';
    router.routerDelegate.addListener(() {
      final path = currentRoutePath(router);
      if (path == last) return;
      last = path;
      _entries.add('${DateTime.now().millisecondsSinceEpoch % 100000} $path');
      if (_entries.length > _size) _entries.removeAt(0);
    });
    if (_hooked) return;
    _hooked = true;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      // Silent reports (a failed picture load) are not the kind this is for.
      if (!details.silent) {
        final what = details.exceptionAsString().split('\n').first;
        debugPrint('[RouteTrail] $what | ${_entries.join(' → ')}');
      }
      previous?.call(details);
    };
  }
}
