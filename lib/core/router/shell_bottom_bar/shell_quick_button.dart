import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../features/messages/chat_icon.dart';
import 'shell_pill_chrome.dart';
import 'shell_pill_metrics.dart';

/// The round button beside the nav pill: same frosted chrome, one tap away.
class ShellQuickButton extends StatelessWidget {
  const ShellQuickButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.icon = HugeIcons.strokeRoundedComputerPhoneSync,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: ShellPillMetrics.height,
        child: ShellPillChrome(
          shape: BoxShape.circle,
          child: InkResponse(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Center(
              child: ChatIcon(icon, size: 24, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
