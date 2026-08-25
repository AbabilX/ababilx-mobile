import 'package:flutter/material.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';
import '../shared/crm_dates.dart';
import '../shared/followup_buckets.dart';
import '../shared/stage_chip.dart';

class FollowupRow extends StatelessWidget {
  const FollowupRow({
    super.key,
    required this.followup,
    required this.onTap,
    this.onMenu,
    this.showMenu = false,
    this.onLongPress,
    this.selected = false,
    this.selecting = false,
    this.onToggleSelect,
  });

  final CrmFollowup followup;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final bool showMenu;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selecting;
  final ValueChanged<bool>? onToggleSelect;

  ContactBadgeTone _statusTone(String label) => switch (label) {
    'Overdue' => ContactBadgeTone.error,
    'Completed' => ContactBadgeTone.tertiary,
    'Cancelled' => ContactBadgeTone.neutral,
    _ => ContactBadgeTone.primary,
  };

  ContactBadgeTone _priorityTone(String p) => switch (p) {
    'high' => ContactBadgeTone.error,
    'low' => ContactBadgeTone.neutral,
    _ => ContactBadgeTone.secondary,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = followupStatusLabel(followup);
    final subtitle = [
      if ((followup.contactCompany ?? '').isNotEmpty) followup.contactCompany!,
      formatCrmDateTime(followup.scheduledAt),
    ].join(' · ');

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.35)
          : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: selecting ? () => onToggleSelect?.call(!selected) : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.55)
                  : colors.outlineVariant.withValues(alpha: 0.65),
              width: 0.9,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              showMenu && !selecting ? 4 : 12,
              12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting) ...[
                  Checkbox(
                    value: selected,
                    onChanged: (v) => onToggleSelect?.call(v ?? false),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              followup.contactName ?? 'Contact',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ContactBadge(
                            label: status,
                            tone: _statusTone(status),
                          ),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: status == 'Overdue'
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if ((followup.stageName ?? '').isNotEmpty)
                            StageChip(
                              name: followup.stageName!,
                              colorHex: followup.stageColor,
                            ),
                          ContactBadge(
                            label: followup.priority,
                            tone: _priorityTone(followup.priority),
                          ),
                          if ((followup.activityTypeName ?? '').isNotEmpty)
                            ContactBadge(
                              label: followup.activityTypeName!,
                              tone: ContactBadgeTone.secondary,
                            ),
                          if ((followup.assigneeName ?? '').isNotEmpty)
                            ContactBadge(
                              label: followup.assigneeName!,
                              tone: ContactBadgeTone.tertiary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showMenu && !selecting)
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: onMenu ?? onTap,
                    tooltip: 'Actions',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
