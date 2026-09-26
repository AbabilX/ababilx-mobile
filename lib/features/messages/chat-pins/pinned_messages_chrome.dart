import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_bar_back_button.dart';
import '../chat_icon.dart';

/// Telegram's floating header: a round back button, a title pill and, while
/// there is something to clear, "Unpin all" on the right — all over a fade,
/// so the pins scroll underneath instead of stopping at an app bar.
class PinnedMessagesTopBar extends StatelessWidget {
  const PinnedMessagesTopBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

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
              child: Center(
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

/// "Unpin all" in the header: an icon and a short label on a pill, a spinner
/// while the unpins run ([onPressed] null).
class PinnedMessagesUnpinAllButton extends StatelessWidget {
  const PinnedMessagesUnpinAllButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Pill(
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: onPressed == null
                ? const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatIcon(
                        HugeIcons.strokeRoundedPinOff,
                        size: 20,
                        color: colors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
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
