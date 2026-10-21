/// All tab: "Add new friends" stays put through this many rows. Past it,
/// the row is tucked off the top until a pull brings it back.
const int addFriendsVisibleThroughCount = 5;

/// How far a pull at the top must travel before the tucked row locks open.
const double addFriendsRevealDistance = 72;

/// Laid-out height of the row plus the divider under it. The pull slides
/// the list by this much instead of inserting a row, so the chats are not
/// rebuilt while the row opens.
const double addFriendsRowExtent = 81;

/// How long a pulled-open row stays before it tucks itself away again.
const Duration addFriendsRevealHold = Duration(seconds: 5);

bool addFriendsHeaderCollapses(int entryCount) =>
    entryCount > addFriendsVisibleThroughCount;

/// Further pull, after the row is open, that starts refresh.
///
/// The same fraction [RefreshIndicator] uses (a quarter of the viewport),
/// and never so short that opening the row and refreshing are one pixel.
double addFriendsRefreshDistance(double viewportDimension) {
  final span = viewportDimension * 0.25;
  if (span < 48) return 48;
  return span;
}

/// Finger-pull at the top of a list whose Add-friends row is tucked away.
///
/// The first [addFriendsRevealDistance] pixels open the row. Pulling on
/// past that, by [addFriendsRefreshDistance], is refresh. Releasing before
/// the row locks open tucks it away again.
class AddFriendsPullGate {
  double _intoReveal = 0;
  double _afterOpen = 0;
  bool open = false;
  bool _refreshFired = false;

  /// 0 while tucked, 1 once the row is fully on screen.
  double get reveal {
    if (open) return 1;
    return (_intoReveal / addFriendsRevealDistance).clamp(0.0, 1.0);
  }

  /// Finger moved down at the top by [delta] pixels.
  ///
  /// True the moment this pull should start a refresh.
  bool dragged(double delta, {required double refreshDistance}) {
    if (delta <= 0 || _refreshFired) return false;
    if (!open) {
      _intoReveal += delta;
      if (_intoReveal < addFriendsRevealDistance) return false;
      _afterOpen = _intoReveal - addFriendsRevealDistance;
      _intoReveal = addFriendsRevealDistance;
      open = true;
    } else {
      _afterOpen += delta;
    }
    if (_afterOpen < refreshDistance) return false;
    _refreshFired = true;
    return true;
  }

  /// Finger up. A partial reveal tucks away; a row that locked open stays.
  void released() {
    _refreshFired = false;
    _afterOpen = 0;
    if (!open) _intoReveal = 0;
  }

  /// The row scrolled off the top, or the list grew past the limit.
  void close() {
    open = false;
    _intoReveal = 0;
    _afterOpen = 0;
    _refreshFired = false;
  }
}
