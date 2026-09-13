import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Circular back / edit controls that float over the details header.
///
/// When [onBanner] is true the fill is a dark scrim so the icons stay readable
/// on any cover photo; on a plain header they take the surface tint instead.
class DetailsFloatingChrome extends StatelessWidget {
  const DetailsFloatingChrome({
    super.key,
    required this.onBack,
    this.onEdit,
    this.onBanner = false,
    this.title,
  });

  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final bool onBanner;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DetailsFloatingButton(
            onBanner: onBanner,
            icon: const ChatIcon(HugeIcons.strokeRoundedArrowLeft01),
            tooltip: 'Back',
            onPressed: onBack,
          ),
          if ((title ?? '').isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: onBanner ? Colors.white : null,
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          if (onEdit != null)
            DetailsFloatingButton(
              onBanner: onBanner,
              icon: const ChatIcon(HugeIcons.strokeRoundedEdit02),
              tooltip: 'Edit group',
              onPressed: onEdit!,
            )
          else
            const SizedBox(width: DetailsFloatingButton.size),
        ],
      ),
    );
  }
}

class DetailsFloatingButton extends StatelessWidget {
  const DetailsFloatingButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onBanner = false,
    this.tooltip,
  });

  static const double size = 40;

  final Widget icon;
  final VoidCallback onPressed;
  final bool onBanner;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = onBanner
        ? Colors.black.withValues(alpha: 0.45)
        : colors.surfaceContainerHighest.withValues(alpha: 0.92);
    final foreground = onBanner ? Colors.white : colors.onSurface;

    final button = Material(
      color: background,
      elevation: onBanner ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: foreground, size: 22),
              child: icon,
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
