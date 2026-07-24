import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Unfocused Slack bar: + | Message name | mic
class ComposerCollapsed extends StatelessWidget {
  const ComposerCollapsed({
    super.key,
    required this.hint,
    required this.onFocusTap,
    required this.onPlus,
    this.onMic,
  });

  final String hint;
  final VoidCallback onFocusTap;
  final VoidCallback onPlus;
  final VoidCallback? onMic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _CircleAction(
                icon: HugeIcons.strokeRoundedAdd01,
                onTap: onPlus,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onFocusTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onMic,
                tooltip: 'Voice',
                icon: ChatIcon(
                  HugeIcons.strokeRoundedMic01,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: ChatIcon(icon, size: 22, color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}
