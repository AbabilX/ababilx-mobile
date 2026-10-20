import 'package:flutter/material.dart';

import '../../messages/chat_icon.dart';

/// One shortcut tile: the icon in a tinted circle, the title, one line of
/// count. Something new behind it takes the primary container and a dot;
/// something gone wrong turns the count red.
class QuickViewCard extends StatelessWidget {
  const QuickViewCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.attention = false,
    this.alert = false,
  });

  static const width = 164.0;

  /// Line height of both text lines. Set on the text itself, so the font's
  /// own (taller) metrics cannot overflow the sum below.
  static const _line = 1.3;

  /// From the parts, through the phone's font scale, so an enlarged system
  /// font grows the tile instead of overflowing it. +4 is rounding slack.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return 14 +
        36 +
        10 +
        scale.scale(14) * _line +
        scale.scale(12) * _line +
        14 +
        4;
  }

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool attention;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = attention
        ? colors.primaryContainer
        : colors.surfaceContainerHigh;
    final ink = attention ? colors.onPrimaryContainer : colors.onSurface;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: width,
          height: heightFor(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: ChatIcon(icon, size: 18, color: colors.primary),
                    ),
                    const Spacer(),
                    if (attention || alert)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: alert ? colors.error : colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: _line,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: _line,
                    color: alert ? colors.error : ink.withValues(alpha: 0.7),
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
