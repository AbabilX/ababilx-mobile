import 'package:flutter/material.dart';

import 'package:hugeicons/hugeicons.dart';

import 'app_bar_back_button.dart';

/// A form page's floating header (new task, new snippet), cut from the same
/// capsules as the Pins and members pages: round back, title pill, and Send as an accent
/// capsule on the right. A null [onSend] dims it (uploading, or sending).
class CapsuleFormHeader extends StatelessWidget {
  const CapsuleFormHeader({
    super.key,
    required this.title,
    required this.sendLabel,
    required this.onBack,
    required this.onSend,
    this.onSendLater,
  });

  final String title;
  final String sendLabel;
  final VoidCallback onBack;
  final VoidCallback? onSend;

  /// Send held down: send later. Off while [onSend] is.
  final VoidCallback? onSendLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final top = MediaQuery.viewPaddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surface, colors.surface.withValues(alpha: 0)],
          stops: const [0.6, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 16),
        child: Row(
          children: [
            _Pill(
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(child: AppBarBackIcon()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: onSend == null ? 0.5 : 1,
              child: Material(
                color: colors.primary,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSend,
                  onLongPress: onSend == null ? null : onSendLater,
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedSent,
                            size: 18,
                            color: colors.onPrimary,
                            strokeWidth: 1.8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sendLabel,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
