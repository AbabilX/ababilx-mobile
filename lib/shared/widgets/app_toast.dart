import 'package:flutter/material.dart';

import 'app_toast_card.dart';

const Duration _visibleFor = Duration(milliseconds: 2600);

// A toast that offers something to press stays long enough to be pressed.
const Duration _visibleWithAction = Duration(seconds: 6);

// One toast at a time. A second replaces the first rather than stacking on it,
// because two overlapping cards at the same coordinates read as one flickering
// card.
OverlayEntry? _current;

/// Shows a short confirmation that drops in from the top of the screen.
///
/// Deliberately not a SnackBar. A SnackBar lives at the bottom, under the
/// composer, the bottom bar and — the case this was written for — a full-screen
/// picker that is being popped at the same moment. Confirming an action the
/// user just took in a sheet is exactly where the bottom of the screen is least
/// likely to be looked at, and where the widget is most likely to be torn down
/// with the route that showed it.
///
/// The entry goes into the ROOT overlay, so it outlives the route that asked
/// for it: `showAppToast(...)` immediately followed by `Navigator.pop()` is the
/// normal way to call this.
void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration? duration,
  String? actionLabel,
  VoidCallback? onAction,
}) => showAppToastIn(
  Overlay.maybeOf(context, rootOverlay: true),
  message,
  isError: isError,
  duration: duration,
  actionLabel: actionLabel,
  onAction: onAction,
);

/// Takes the toast on screen down now — for a "Saving…" notice whose work
/// finished before its time ran out.
void hideAppToast() => _remove(_current);

/// [showAppToast] for a caller that outlives its own context: look the root
/// overlay up while the widget is still mounted, keep it, and report an
/// async result on it later. A Navigator's context does not work for this —
/// it sits ABOVE the navigator's overlay, so the lookup finds nothing.
void showAppToastIn(
  OverlayState? overlay,
  String message, {
  bool isError = false,
  Duration? duration,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (overlay == null || !overlay.mounted || message.trim().isEmpty) return;
  _remove(_current);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AppToastCard(
      message: message,
      isError: isError,
      visibleFor:
          duration ?? (actionLabel == null ? _visibleFor : _visibleWithAction),
      actionLabel: actionLabel,
      onAction: onAction,
      onGone: () {
        if (identical(_current, entry)) _current = null;
        _remove(entry);
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

void _remove(OverlayEntry? entry) {
  if (entry == null) return;
  if (identical(_current, entry)) _current = null;
  // An entry already detached throws; there is nothing to do about it and
  // nothing to report, since the only outcome either way is that it is gone.
  try {
    entry.remove();
  } catch (_) {}
}
