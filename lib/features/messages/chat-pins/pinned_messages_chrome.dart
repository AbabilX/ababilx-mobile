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
  });

  final String title;
  final Widget? trailing;
  final Widget? middle;

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
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 24),
        child: Row(
          children: [
            _Pill(
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(child: AppBarBackIcon()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  middle ??
                  Center(
                    child: _Pill(
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
            const SizedBox(width: 8),
            // Keeps the title centred on the screen when there is no action.
            trailing ?? const SizedBox(width: 44),
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
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = _Pill(
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
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.shape, required this.child});

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
