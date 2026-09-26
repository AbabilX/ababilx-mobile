import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/khaam_covers.dart';

/// Under the message: how to scratch plus a Reveal all escape while the foil
/// is on (and for anyone who cannot scratch), Done once it is off.
class KhaamOpenFooter extends StatelessWidget {
  const KhaamOpenFooter({
    super.key,
    required this.cover,
    required this.sealed,
    required this.helpLabel,
    required this.revealLabel,
    required this.doneLabel,
    required this.onReveal,
    required this.onDone,
  });

  final KhaamCover cover;
  final bool sealed;
  final String helpLabel;
  final String revealLabel;
  final String doneLabel;
  final VoidCallback onReveal;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: sealed
          ? Row(
              key: const ValueKey('sealed'),
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedTouch01,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    helpLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onReveal,
                  style: TextButton.styleFrom(foregroundColor: cover.flap),
                  child: Text(revealLabel),
                ),
              ],
            )
          : SizedBox(
              key: const ValueKey('open'),
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cover.flap,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onDone,
                child: Text(doneLabel),
              ),
            ),
    );
  }
}
