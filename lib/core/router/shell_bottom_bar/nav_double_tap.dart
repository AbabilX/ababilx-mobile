/// Spots a second tap on the navigation bar.
///
/// Not a double-tap recogniser: one of those holds every single tap back for
/// 300 ms while it waits for a second, and a tab that answers late reads as a
/// slow app. The first tap acts at once; this only notices the one after it.
class NavDoubleTap {
  static const window = Duration(milliseconds: 300);

  DateTime? _last;

  /// True when this tap follows another within [window].
  bool hit([DateTime? now]) {
    final at = now ?? DateTime.now();
    final last = _last;
    if (last != null && at.difference(last) <= window) {
      _last = null;
      return true;
    }
    _last = at;
    return false;
  }
}

/// One for the app's single navigation bar.
final navDoubleTap = NavDoubleTap();
