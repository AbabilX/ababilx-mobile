import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum RuleStatus { running, paused, scheduled, sent }

class RuleStatusBadge extends StatelessWidget {
  const RuleStatusBadge({super.key, required this.status});

  final RuleStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bgColor) = switch (status) {
      RuleStatus.running => ('Running', AppColors.green, const Color(0x2022C55E)),
      RuleStatus.paused => ('Paused', AppColors.textMuted, AppColors.surface2),
      RuleStatus.scheduled => ('Scheduled', AppColors.amber, const Color(0x20F59E0B)),
      RuleStatus.sent => ('Sent', AppColors.indigo, AppColors.indigoGlow),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == RuleStatus.running) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
