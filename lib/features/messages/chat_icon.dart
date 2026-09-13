import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Thin HugeIcon wrapper so call sites stay short.
class ChatIcon extends StatelessWidget {
  const ChatIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.2,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;

  /// Thinner than the package default (1.5) so chrome reads light, not bold.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      size: size,
      color: color ?? IconTheme.of(context).color,
      strokeWidth: strokeWidth,
    );
  }
}
