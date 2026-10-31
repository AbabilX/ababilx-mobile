import 'package:flutter/material.dart';

/// Multi-select chrome around one conversation row: the check circle in the
/// gutter, the shift that makes room for it, and the shade over a selected
/// message.
///
/// The reference app's numbers, from `MultiselectItemDecoration`: the row's
/// content is pushed to a 48dp gutter, the circle is 22dp across at 17dp from
/// the screen edge, and the enter/exit animation is 150ms. It draws all of that
/// as a RecyclerView decoration over an untouched item; a Flutter row has no
/// equivalent, so the gutter is real layout — which is why the list's own
/// horizontal padding lives in here rather than on the ListView. The shade has
/// to reach both screen edges, and a padded list would inset it.
class SelectableMessageRow extends StatelessWidget {
  const SelectableMessageRow({
    super.key,
    required this.selecting,
    required this.selected,
    required this.hasWallpaper,
    required this.child,
  });

  final bool selecting;
  final bool selected;
  final bool hasWallpaper;
  final Widget child;

  /// `conversation_individual_left_gutter`, the list's resting side inset.
  static const restingGutter = 16.0;

  /// The gutter the reference app shifts content to while selecting.
  static const selectGutter = 48.0;

  static const _circleInset = 17.0;
  static const _circleDiameter = 22.0;
  static const _duration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The reference app: transparent black over a wallpaper, transparent white
    // in dark theme, a wash of the accent in light.
    final shade = hasWallpaper
        ? Colors.black.withValues(alpha: 0.20)
        : isDark
        ? Colors.white.withValues(alpha: 0.20)
        : scheme.primary.withValues(alpha: 0.13);

    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOut,
      color: selected ? shade : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            width: selecting ? selectGutter : restingGutter,
            // Height is pinned to the circle and the row centres it: a Row
            // hands its children an unbounded height, and an OverflowBox given
            // one tries to be infinitely tall.
            height: _circleDiameter,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: _circleInset + _circleDiameter,
              minHeight: _circleDiameter,
              maxHeight: _circleDiameter,
              child: Padding(
                padding: const EdgeInsets.only(left: _circleInset),
                child: AnimatedOpacity(
                  duration: _duration,
                  opacity: selecting ? 1 : 0,
                  child: _SelectionCircle(selected: selected),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: restingGutter),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = SelectableMessageRow._circleDiameter;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: SelectableMessageRow._duration,
        child: selected
            ? Icon(
                Icons.check_circle,
                key: const ValueKey(true),
                size: size,
                color: scheme.primary,
              )
            : DecoratedBox(
                key: const ValueKey(false),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    // The reference app's unselected ring: 1.5dp, and
                    // deliberately faint — an empty circle per row must not
                    // read as a control the eye has to deal with.
                    color: scheme.onSurface.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              ),
      ),
    );
  }
}
