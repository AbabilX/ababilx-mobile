import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_bar_back_button.dart';
import '../chat_icon.dart';

/// Telegram's floating header: a round back button and a title pill over a
/// fade, so the pins scroll underneath instead of stopping at an app bar.
class PinnedMessagesTopBar extends StatelessWidget {
  const PinnedMessagesTopBar({super.key, required this.title});

  final String title;

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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _Pill(
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: SizedBox.square(
                    dimension: 44,
                    child: const Center(child: AppBarBackIcon()),
                  ),
                ),
              ),
            ),
            _Pill(
              shape: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full-width "Unpin all messages" bar pinned to the bottom.
class PinnedMessagesUnpinAllBar extends StatelessWidget {
  const PinnedMessagesUnpinAllBar({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 12),
      child: _Pill(
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Center(
              child: onPressed == null
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
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

/// Centred icon + text for the empty and failed states.
class PinnedMessagesNotice extends StatelessWidget {
  const PinnedMessagesNotice({
    super.key,
    required this.title,
    this.body,
    this.action,
  });

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.94,
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedPin,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                if (body != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                ?action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
