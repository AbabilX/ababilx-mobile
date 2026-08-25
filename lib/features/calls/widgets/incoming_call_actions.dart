import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decline / Answer for a ringing call, in the shape a phone user already
/// knows: two large circles at the bottom edge, red on the left, green on the
/// right, each with its label underneath. The answer button breathes so the
/// eye lands on it.
class IncomingCallActions extends StatelessWidget {
  const IncomingCallActions({
    super.key,
    required this.onDecline,
    required this.onAccept,
    this.declineLabel = 'Decline',
    this.acceptLabel = 'Accept',
    this.acceptIcon = Icons.call_rounded,
  });

  final VoidCallback onDecline;
  final VoidCallback onAccept;

  /// A channel call denies and joins rather than declining and accepting.
  final String declineLabel;
  final String acceptLabel;
  final IconData acceptIcon;

  @override
  Widget build(BuildContext context) => Row(
    // Edge padding belongs to the screen around this, so a dialog and a full
    // screen can both place the buttons where their own margins put them.
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _CallAction(
        label: declineLabel,
        icon: Icons.call_end_rounded,
        color: const Color(0xFFE53935),
        onPressed: onDecline,
      ),
      _CallAction(
        label: acceptLabel,
        icon: acceptIcon,
        color: const Color(0xFF22C55E),
        breathing: true,
        onPressed: onAccept,
      ),
    ],
  );
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.breathing = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool breathing;

  static const _size = 76.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final button = Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            // Answering or refusing a call is worth a confirming tap back.
            HapticFeedback.mediumImpact();
            onPressed();
          },
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon, size: 34, color: Colors.white),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (breathing) _Breathing(child: button) else button,
        const SizedBox(height: 12),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Breathing extends StatefulWidget {
  const _Breathing({required this.child});

  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.07,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
