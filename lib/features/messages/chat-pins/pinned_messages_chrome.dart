import 'package:flutter/material.dart';

import '../../../shared/widgets/app_bar_back_button.dart';
import '../chat_icon.dart';

/// Telegram's floating header: a round back button, a title pill and an
/// optional round action on the right — all over a fade, so the list scrolls
/// underneath instead of stopping at an app bar.
/// Also the group members page's header; [middle] replaces the title
/// capsule there while searching.
class PinnedMessagesTopBar extends StatelessWidget {
  const PinnedMessagesTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.middle,
    this.bottomPadding = 24,
    this.reserveTrailing = true,
    this.backLabel,
  });

  final String title;
  final Widget? trailing;
  final Widget? middle;

  /// Room under the capsules: 24 leaves the fade to melt into a list that
  /// scrolls beneath; a header that sits above its list asks for less.
  final double bottomPadding;

  /// With no [trailing], keep a 44dp gap so the title stays centred (true), or
  /// let the middle run to the right edge (false).
  final bool reserveTrailing;

  /// Words beside the back arrow, turning the round button into a capsule —
  /// for a header with nothing on its right to spend the room on.
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.viewPaddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surface.withValues(alpha: 0.9),
            colors.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, bottomPadding),
        child: Row(
          children: [
            HeaderPill(
              shape: backLabel == null
                  ? const CircleBorder()
                  : const StadiumBorder(),
              child: InkWell(
                customBorder: backLabel == null
                    ? const CircleBorder()
                    : const StadiumBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  height: 44,
                  width: backLabel == null ? 44 : null,
                  child: backLabel == null
                      ? const Center(child: AppBarBackIcon())
                      : Padding(
                          padding: const EdgeInsets.only(left: 10, right: 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppBarBackIcon(),
                              const SizedBox(width: 4),
                              Text(
                                backLabel!,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  middle ??
                  Center(
                    child: HeaderPill(
                      shape: const StadiumBorder(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
            ),
            if (trailing != null || reserveTrailing) ...[
              const SizedBox(width: 8),
              // Keeps the title centred on the screen when there is no action.
              trailing ?? const SizedBox(width: 44),
            ],
          ],
        ),
      ),
    );
  }
}

/// A round 44dp header button on the same frosted fill (search, close).
class PinnedMessagesCircleButton extends StatelessWidget {
  const PinnedMessagesCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final List<List<dynamic>> icon;

  /// Null draws the button dimmed and inert (a call that cannot start now).
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: HeaderPill(
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: ChatIcon(
                icon,
                size: 22,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// The frosted capsule every floating header piece is cut from.
class HeaderPill extends StatelessWidget {
  const HeaderPill({super.key, required this.shape, required this.child});

  final ShapeBorder shape;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
    shape: shape,
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
