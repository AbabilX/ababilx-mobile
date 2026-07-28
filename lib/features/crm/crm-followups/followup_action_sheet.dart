import 'package:flutter/material.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';
import '../shared/crm_dates.dart';
import '../shared/followup_buckets.dart';
import '../shared/stage_chip.dart';

enum FollowupSheetAction { complete, edit, delete, openDetail }

/// Web FollowupActionDialog — summary + pending Complete/Edit; Delete if canDelete.
Future<FollowupSheetAction?> showFollowupActionSheet(
  BuildContext context, {
  required CrmFollowup followup,
  required bool canUpdate,
  required bool canDelete,
  bool showOpenDetail = true,
}) {
  final pending = followup.isPending;
  final status = followupStatusLabel(followup);
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  return showModalBottomSheet<FollowupSheetAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              followup.activityTypeName?.isNotEmpty == true
                  ? followup.activityTypeName!
                  : 'Follow-up',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if ((followup.contactName ?? '').isNotEmpty)
              Text(
                followup.contactName!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              formatCrmDateTime(followup.scheduledAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
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
                  tone: followup.priority == 'high'
                      ? ContactBadgeTone.error
                      : ContactBadgeTone.secondary,
                ),
                ContactBadge(
                  label: status,
                  tone: status == 'Overdue'
                      ? ContactBadgeTone.error
                      : ContactBadgeTone.primary,
                ),
                if ((followup.assigneeName ?? '').isNotEmpty)
                  ContactBadge(
                    label: followup.assigneeName!,
                    tone: ContactBadgeTone.tertiary,
                  ),
              ],
            ),
            if (followup.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                followup.notes,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (pending && canUpdate)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: colors.tertiary,
                ),
                title: const Text('Complete'),
                onTap: () => Navigator.pop(ctx, FollowupSheetAction.complete),
              ),
            if (pending && canUpdate)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.edit_calendar_outlined,
                  color: colors.primary,
                ),
                title: const Text('Edit / reschedule'),
                onTap: () => Navigator.pop(ctx, FollowupSheetAction.edit),
              ),
            if (canDelete)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: colors.error),
                title: Text('Delete', style: TextStyle(color: colors.error)),
                onTap: () => Navigator.pop(ctx, FollowupSheetAction.delete),
              ),
            if (showOpenDetail)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open details'),
                onTap: () => Navigator.pop(ctx, FollowupSheetAction.openDetail),
              ),
          ],
        ),
      ),
    ),
  );
}
