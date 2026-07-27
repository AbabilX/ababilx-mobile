import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// WhatsApp-style voice recording bottom sheet: timer + waveform +
/// delete / pause / send.
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
    required this.preparingLabel,
    required this.sendingLabel,
    required this.onDelete,
    required this.onPauseToggle,
    required this.onSend,
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
  final String preparingLabel;
  final String sendingLabel;
  final VoidCallback onDelete;
  final VoidCallback onPauseToggle;
  final VoidCallback onSend;
  final VoidCallback onViewOnceToggle;

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
        oldWidget.uploading != widget.uploading ||
        oldWidget.paused != widget.paused) {
      _syncWave();
    }
  }

  void _syncWave() {
    final active = !widget.preparing && !widget.uploading && !widget.paused;
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

  String _formatDuration(Duration elapsed) {
    final total = elapsed.inSeconds.clamp(0, 3599);
    final raw = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
    if (!widget.useBengaliDigits) return raw;
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return raw.split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : bn[i];
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.preparing || widget.uploading;
    final pauseText = widget.paused ? widget.resumeLabel : widget.pauseLabel;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
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
                  SizedBox(
                    width: 48,
                    child: Text(
                      _formatDuration(widget.elapsed),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: widget.uploading
                          ? Center(
                              child: Text(
                                widget.sendingLabel,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : widget.preparing
                          ? Center(
                              child: Text(
                                widget.preparingLabel,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _wave,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _WaveformPainter(
                                    progress: _wave.value,
                                    paused: widget.paused,
                                  ),
                                  child: const SizedBox.expand(),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ViewOnceButton(
                    active: widget.viewOnce,
                    onTap: busy ? null : widget.onViewOnceToggle,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _CircleIconButton(
                    background: const Color(0xFFFCE4EC),
                    onTap: busy ? null : widget.onDelete,
                    child: busy && widget.uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFD32F2F),
                            ),
                          )
                        : const ChatIcon(
                            HugeIcons.strokeRoundedDelete02,
                            size: 22,
                            color: Color(0xFFD32F2F),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(40),
                      child: InkWell(
                        onTap: busy ? null : widget.onPauseToggle,
                        borderRadius: BorderRadius.circular(40),
                        child: SizedBox(
                          height: 52,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.paused
                                    ? Icons.mic_rounded
                                    : Icons.pause_rounded,
                                size: 22,
                                color: const Color(0xFF111827),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                pauseText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleIconButton(
                    background: const Color(0xFF1B5E3B),
                    onTap: busy ? null : widget.onSend,
                    child: const Icon(
                      Icons.send_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.background,
    required this.child,
    this.onTap,
  });

  final Color background;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 52, height: 52, child: Center(child: child)),
      ),
    );
  }
}

class _ViewOnceButton extends StatelessWidget {
  const _ViewOnceButton({required this.active, this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(
          painter: _DottedCirclePainter(
            color: active ? const Color(0xFF1B5E3B) : const Color(0xFF9CA3AF),
          ),
          child: Center(
            child: Text(
              '1',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active
                    ? const Color(0xFF1B5E3B)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  _DottedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    const dashCount = 18;
    const dashSweep = math.pi * 2 / dashCount * 0.45;
    for (var i = 0; i < dashCount; i++) {
      final start = i * math.pi * 2 / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.progress, required this.paused});

  final double progress;
  final bool paused;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / 5).floor().clamp(24, 56);
    final paint = Paint()
      ..color = paused ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final midY = size.height / 2;
    final gap = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final phase = i * 0.42;
      final t = progress * math.pi * 2;
      final pulse = paused
          ? 0.35 + (i % 5) * 0.08
          : (math.sin(t + phase) + 1) / 2;
      final h = 4.0 + pulse * (size.height * 0.72);
      final x = gap * i + gap / 2;
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.paused != paused;
}
