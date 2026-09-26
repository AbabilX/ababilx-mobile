import 'package:flutter/material.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_chrome.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/chat_icon.dart';

/// The app's floating bottom capsule dock, laid out exactly like
/// `ShellBottomBar`: one wide capsule, and an optional circle beside it.
class JPackBottomBar extends StatelessWidget {
  const JPackBottomBar({super.key, required this.child, this.action});

  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: ShellPillChrome(
                child: SizedBox(height: ShellPillMetrics.height, child: child),
              ),
            ),
            if (action != null) ...[const SizedBox(width: 10), action!],
          ],
        ),
      ),
    );
  }
}

/// The accent circle beside the dock — send.
class JPackSendPill extends StatelessWidget {
  const JPackSendPill({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final Color color;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = ShellPillMetrics.height;
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: shellPillShadow(Theme.of(context).colorScheme),
        ),
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : ChatIcon(icon, size: 26, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
