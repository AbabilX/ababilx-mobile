import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'recording_bar_parts.dart';
import 'recording_bar_status.dart';

/// Voice recording sheet: timer + waveform, then delete / pause / send.
/// Theme colours only. Live = blinking red dot + moving accent bars; paused =
/// pause glyph + "Paused" + frozen grey bars, so the state is never a guess.
class ComposerRecordingBar extends StatefulWidget {
  const ComposerRecordingBar({
    super.key,
    required this.elapsed,
    required this.preparing,
    required this.uploading,
    required this.paused,
    required this.viewOnce,
    required this.useBengaliDigits,
    required this.pauseLabel,
    required this.resumeLabel,
    required this.pausedLabel,
    required this.preparingLabel,
    required this.sendingLabel,
    required this.onDelete,
    required this.onPauseToggle,
    required this.onSend,
    this.onSendLater,
    required this.onViewOnceToggle,
  });

  final Duration elapsed;
  final bool preparing;
  final bool uploading;
  final bool paused;
  final bool viewOnce;
  final bool useBengaliDigits;
  final String pauseLabel;
  final String resumeLabel;
  final String pausedLabel;
  final String preparingLabel;
  final String sendingLabel;
  final VoidCallback onDelete;
  final VoidCallback onPauseToggle;
  final VoidCallback onSend;

  /// Send held down: send the voice note later.
  final VoidCallback? onSendLater;
  final VoidCallback onViewOnceToggle;

  @override
  State<ComposerRecordingBar> createState() => _ComposerRecordingBarState();
}

class _ComposerRecordingBarState extends State<ComposerRecordingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool get _live => !widget.preparing && !widget.uploading && !widget.paused;

  @override
  void initState() {
    super.initState();
    _syncWave();
  }

  @override
  void didUpdateWidget(covariant ComposerRecordingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWave();
  }

  void _syncWave() {
    if (_live) {
      if (!_wave.isAnimating) _wave.repeat();
    } else if (_wave.isAnimating || _wave.value != 0) {
      _wave
        ..stop()
        ..value = 0;
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
    final text = Theme.of(context).textTheme;
    final busy = widget.preparing || widget.uploading;

    return Material(
      color: colors.surfaceContainerLow,
      elevation: 8,
      shadowColor: colors.shadow.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  RecordingStatusDot(
                    wave: _wave,
                    live: _live,
                    paused: widget.paused,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    recordingClock(
                      widget.elapsed,
                      bengali: widget.useBengaliDigits,
                    ),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.paused
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RecordingMiddleStrip(
                      wave: _wave,
                      paused: widget.paused,
                      note: widget.uploading
                          ? widget.sendingLabel
                          : widget.preparing
                          ? widget.preparingLabel
                          : null,
                      pausedLabel: widget.pausedLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RecordingViewOnceButton(
                    active: widget.viewOnce,
                    onTap: busy ? null : widget.onViewOnceToggle,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  RecordingCircleButton(
                    background: colors.errorContainer,
                    onTap: busy ? null : widget.onDelete,
                    child: ChatIcon(
                      HugeIcons.strokeRoundedDelete02,
                      size: 22,
                      strokeWidth: 1.6,
                      color: colors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RecordingPauseCapsule(
                      icon: widget.paused
                          ? HugeIcons.strokeRoundedMic01
                          : HugeIcons.strokeRoundedPause,
                      label: widget.paused
                          ? widget.resumeLabel
                          : widget.pauseLabel,
                      onTap: busy ? null : widget.onPauseToggle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  RecordingCircleButton(
                    background: colors.primary,
                    onTap: busy ? null : widget.onSend,
                    onLongPress: busy ? null : widget.onSendLater,
                    child: RecordingSendIcon(uploading: widget.uploading),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
