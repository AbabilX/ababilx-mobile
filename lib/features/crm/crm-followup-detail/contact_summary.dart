import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../crm-contacts/contact_avatar.dart';
import '../crm-contacts/contact_badge.dart';
import '../data/models/crm_models.dart';

/// Web ContactSummarySection.
class FollowupContactSummary extends StatelessWidget {
  const FollowupContactSummary({
    super.key,
    required this.lead,
    required this.followup,
  });

  final CrmLead lead;
  final CrmFollowup followup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = (lead.contactCompany ?? '').isNotEmpty
        ? lead.contactCompany!
        : ((lead.contactName ?? '').isNotEmpty
            ? lead.contactName!
            : lead.title);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContactAvatar(name: title, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ContactBadge(
                  label: lead.title.isEmpty ? 'Lead' : lead.title,
                  tone: ContactBadgeTone.primary,
                ),
                const SizedBox(height: 8),
                if ((lead.contactPhone ?? '').isNotEmpty)
                  Text(
                    lead.contactPhone!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if ((lead.contactEmail ?? '').isNotEmpty)
                  Text(
                    lead.contactEmail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if ((followup.assigneeName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Assignee: ${followup.assigneeName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => context.push('/crm/leads/${lead.id}'),
                  child: const Text('Open lead'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
