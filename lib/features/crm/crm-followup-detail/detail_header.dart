import 'package:flutter/material.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';
import '../shared/crm_dates.dart';
import '../shared/followup_buckets.dart';

/// Web DetailHeader — status + when + edit/complete actions.
class FollowupDetailHeader extends StatelessWidget {
  const FollowupDetailHeader({
    super.key,
    required this.followup,
    required this.canEdit,
    required this.canComplete,
    required this.onEdit,
    required this.onComplete,
  });

  final CrmFollowup followup;
  final bool canEdit;
  final bool canComplete;
  final VoidCallback onEdit;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = followupStatusLabel(followup);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Follow-up Details',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ContactBadge(
              label: status,
              tone: status == 'Overdue'
                  ? ContactBadgeTone.error
                  : status == 'Completed'
                  ? ContactBadgeTone.tertiary
                  : ContactBadgeTone.primary,
            ),
            Text(
              formatCrmDateTime(followup.scheduledAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canComplete)
              FilledButton.tonalIcon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Complete'),
              ),
            if (canEdit)
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
          ],
        ),
      ],
    );
  }
}
