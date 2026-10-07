/// Spots a second tap on the navigation bar.
///
/// Not a double-tap recogniser: one of those holds every single tap back for
/// 300 ms while it waits for a second, and a tab that answers late reads as a
/// slow app. The first tap acts at once; this only notices the one after it.
class NavDoubleTap {
  static const window = Duration(milliseconds: 300);

  DateTime? _last;
  Object? _lastTarget;

  /// True when this tap follows another within [window] on the same
  /// [target]. Two different tabs tapped in quick succession are two taps:
  /// the second one is the tab the person wants.
  bool hit([DateTime? now, Object? target]) {
    final at = now ?? DateTime.now();
    final last = _last;
    if (last != null &&
        target == _lastTarget &&
        at.difference(last) <= window) {
      _last = null;
      return true;
    }
    _last = at;
    _lastTarget = target;
    return false;
  }
}

/// One for the app's single navigation bar.
final navDoubleTap = NavDoubleTap();
