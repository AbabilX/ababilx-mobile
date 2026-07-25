import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';
import '../shared/followup_buckets.dart';

class FollowupSideCards extends StatelessWidget {
  const FollowupSideCards({
    super.key,
    required this.lead,
    required this.followup,
    required this.notes,
    required this.leadFollowups,
    this.onEdit,
  });

  final CrmLead lead;
  final CrmFollowup followup;
  final List<CrmNote> notes;
  final List<CrmFollowup> leadFollowups;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final nextPending = leadFollowups
        .where((f) => f.isPending && f.id != followup.id)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final next = nextPending.isEmpty ? null : nextPending.first;

    return Column(
      children: [
        _Card(
          title: 'Contact Information',
          child: Column(
            children: [
              if ((lead.contactName ?? '').isNotEmpty)
                _InfoRow(label: 'Contact Person', value: lead.contactName!),
              if ((lead.contactPhone ?? '').isNotEmpty)
                _InfoRow(label: 'Phone', value: lead.contactPhone!),
              if ((lead.contactEmail ?? '').isNotEmpty)
                _InfoRow(label: 'Email', value: lead.contactEmail!),
              if ((lead.contactName ?? '').isEmpty &&
                  (lead.contactPhone ?? '').isEmpty &&
                  (lead.contactEmail ?? '').isEmpty)
                const CrmEmpty(message: 'No contact details'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Next Follow-up',
          trailing: onEdit != null && followup.isPending
              ? TextButton(onPressed: onEdit, child: const Text('Edit'))
              : null,
          child: next == null && !followup.isPending
              ? const CrmEmpty(message: 'No upcoming follow-up')
              : _NextBody(followup: next ?? followup),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Notes',
          trailing: TextButton(
            onPressed: () => context.push('/crm/leads/${lead.id}'),
            child: const Text('All'),
          ),
          child: notes.isEmpty
              ? const CrmEmpty(message: 'No notes yet')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final n in notes.take(3)) ...[
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((n.authorName ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            n.authorName!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _NextBody extends StatelessWidget {
  const _NextBody({required this.followup});
  final CrmFollowup followup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = followupStatusLabel(followup);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatCrmDateTime(followup.scheduledAt),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ContactBadge(label: status, tone: ContactBadgeTone.primary),
            ContactBadge(
              label: followup.priority,
              tone: followup.priority == 'high'
                  ? ContactBadgeTone.error
                  : ContactBadgeTone.secondary,
            ),
            if ((followup.activityTypeName ?? '').isNotEmpty)
              ContactBadge(
                label: followup.activityTypeName!,
                tone: ContactBadgeTone.neutral,
              ),
          ],
        ),
        if (followup.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            followup.notes,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
