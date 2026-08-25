import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../features/profile/data/profile_repository.dart';

class PlanExpiredDialog extends StatelessWidget {
  const PlanExpiredDialog({
    super.key,
    required this.user,
    required this.onDismiss,
  });

  final AppUser user;
  final VoidCallback onDismiss;

  String _untilLabel() {
    final until = user.premiumUntil;
    if (until == null || until.isEmpty) return 'recently';
    final d = DateTime.tryParse(until);
    if (d == null) return until;
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: AppColors.amber),
          SizedBox(width: 8),
          Expanded(child: Text('Premium plan ended')),
        ],
      ),
      content: Text(
        'Your Premium access ended on ${_untilLabel()}. '
        'Standup rules, auto-commit jobs, and weekly digests were paused. '
        'Check your email if notifications are enabled.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        FilledButton(onPressed: onDismiss, child: const Text('Got it')),
      ],
    );
  }
}
