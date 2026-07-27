import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ComposerRecordingBar extends StatefulWidget {
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
  State<ComposerRecordingBar> createState() => _ComposerRecordingBarState();
}

class _ComposerRecordingBarState extends State<ComposerRecordingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncWave();
  }

  @override
  void didUpdateWidget(covariant ComposerRecordingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preparing != widget.preparing ||
        oldWidget.uploading != widget.uploading) {
      _syncWave();
    }
  }

  void _syncWave() {
    final active = !widget.preparing && !widget.uploading;
    if (active) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seconds = widget.elapsed.inSeconds;
    final duration =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final label = widget.uploading
        ? widget.sendingLabel
        : widget.preparing
        ? widget.preparingLabel
        : widget.releaseLabel;

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
                child: widget.uploading
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
              if (!widget.uploading)
                Expanded(
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(12, (index) {
                          final phase = index * 0.55;
                          final t = _wave.value * math.pi * 2;
                          final pulse = widget.preparing
                              ? 0.22
                              : (math.sin(t + phase) + 1) / 2;
                          final height = 6.0 + pulse * 18.0;
                          return Container(
                            width: 3,
                            height: height,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(
                                alpha: 0.35 + pulse * 0.55,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: widget.uploading
                      ? colors.onSurfaceVariant
                      : colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
