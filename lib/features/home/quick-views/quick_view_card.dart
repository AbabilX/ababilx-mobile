import 'package:flutter/material.dart';

import '../../messages/chat_icon.dart';

/// A compact Home shortcut — chip/badge, not a tall card. Icon + title +
/// count in one row. Something new takes a soft primary wash; something
/// gone wrong turns the count red.
class QuickViewCard extends StatelessWidget {
  const QuickViewCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
    required this.accentFill,
    this.attention = false,
    this.alert = false,
  });

  static const _line = 1.2;

  /// Chip height through the phone's font scale.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return (8 + scale.scale(13) * _line + 8).clamp(32.0, 48.0) + 4;
  }

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final Color accentFill;
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
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentFill,
                  shape: BoxShape.circle,
                ),
                child: ChatIcon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: _line,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: _line,
                  fontWeight: FontWeight.w500,
                  color: alert ? colors.error : ink.withValues(alpha: 0.55),
                ),
              ),
              if (alert || attention) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: alert ? colors.error : colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
