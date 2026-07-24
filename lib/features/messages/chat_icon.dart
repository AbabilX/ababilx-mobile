import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Thin HugeIcon wrapper so call sites stay short.
class ChatIcon extends StatelessWidget {
  const ChatIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      size: size,
      color: color ?? IconTheme.of(context).color,
    );
  }
}
