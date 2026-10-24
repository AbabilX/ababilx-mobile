import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'recording_waveform.dart';

/// Round 52dp button of the recording sheet. Dimmed while [onTap] is null.
class RecordingCircleButton extends StatelessWidget {
  const RecordingCircleButton({
    super.key,
    required this.background,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.tooltip,
  });

  final Color background;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedOpacity(
      opacity: onTap == null && onLongPress == null ? 0.38 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(width: 52, height: 52, child: Center(child: child)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// The wide Pause / Resume capsule in the middle of the sheet.
class RecordingPauseCapsule extends StatelessWidget {
  const RecordingPauseCapsule({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AnimatedOpacity(
      opacity: onTap == null ? 0.38 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: colors.secondaryContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChatIcon(
                  icon,
                  size: 22,
                  strokeWidth: 1.6,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSecondaryContainer,
                    ),
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

/// View-once switch: a dashed ring around "1", accent while on.
class RecordingViewOnceButton extends StatelessWidget {
  const RecordingViewOnceButton({super.key, required this.active, this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = active ? colors.primary : colors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(
          painter: DottedCirclePainter(
            color: active ? colors.primary : colors.outline,
          ),
          child: Center(
            child: Text(
              '1',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Send arrow, or a spinner while the voice note uploads.
class RecordingSendIcon extends StatelessWidget {
  const RecordingSendIcon({super.key, required this.uploading});

  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    if (!uploading) {
      return ChatIcon(
        HugeIcons.strokeRoundedSent,
        size: 22,
        strokeWidth: 1.6,
        color: onPrimary,
      );
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: onPrimary),
    );
  }
}
