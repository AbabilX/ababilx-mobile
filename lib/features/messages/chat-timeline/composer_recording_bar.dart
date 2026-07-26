import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ComposerRecordingBar extends StatelessWidget {
  const ComposerRecordingBar({
    super.key,
    required this.elapsed,
    required this.preparing,
    required this.uploading,
    required this.releaseLabel,
    required this.preparingLabel,
    required this.sendingLabel,
  });

  final Duration elapsed;
  final bool preparing;
  final bool uploading;
  final String releaseLabel;
  final String preparingLabel;
  final String sendingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seconds = elapsed.inSeconds;
    final duration =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final label = uploading
        ? sendingLabel
        : preparing
        ? preparingLabel
        : releaseLabel;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.errorContainer,
                ),
                alignment: Alignment.center,
                child: uploading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onErrorContainer,
                        ),
                      )
                    : ChatIcon(
                        HugeIcons.strokeRoundedMic01,
                        size: 20,
                        color: colors.onErrorContainer,
                      ),
              ),
              const SizedBox(width: 12),
              Text(
                duration,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              if (!uploading)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      12,
                      (index) => Container(
                        width: 3,
                        height: 8.0 + ((index * 7) % 18),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(
                            alpha: index.isEven ? 0.9 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: uploading ? colors.onSurfaceVariant : colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
