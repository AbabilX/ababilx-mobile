import 'dart:async';

import 'package:flutter/material.dart';

const Duration _visibleFor = Duration(milliseconds: 2600);
const Duration _slide = Duration(milliseconds: 220);

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
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || message.trim().isEmpty) return;
  _remove(_current);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastCard(
      message: message,
      isError: isError,
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

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.isError,
    required this.onGone,
  });

  final String message;
  final bool isError;
  final VoidCallback onGone;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _slide,
  );
  Timer? _hold;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hold = Timer(_visibleFor, _dismiss);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _hold?.cancel();
    if (mounted) await _controller.reverse();
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final background = widget.isError
        ? colors.errorContainer
        : colors.inverseSurface;
    final foreground = widget.isError
        ? colors.onErrorContainer
        : colors.onInverseSurface;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(curve),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_rounded,
                      size: 20,
                      color: foreground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
