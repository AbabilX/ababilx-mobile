import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';
import 'complete_followup_sheet.dart';
import 'followup_form_sheet.dart';

class FollowupsTab extends ConsumerWidget {
  const FollowupsTab({
    super.key,
    required this.lead,
    required this.followups,
    required this.activityTypes,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
  });

  final CrmLead lead;
  final List<CrmFollowup> followups;
  final List<CrmActivityType> activityTypes;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;

  bool get _hasOpen => followups.any((f) => f.isPending);

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final body = await showFollowupFormSheet(
      context,
      lead: lead,
      activityTypes: activityTypes,
    );
    if (body == null) return;
    try {
      await ref.read(crmRepositoryProvider).createFollowup(body);
      invalidateLeadDetail(ref, lead.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up scheduled')),
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('open_followup')
                ? 'This lead already has an open follow-up'
                : msg,
          ),
        ),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CrmFollowup f,
  ) async {
    final body = await showFollowupFormSheet(
      context,
      lead: lead,
      activityTypes: activityTypes,
      initial: f,
    );
    if (body == null) return;
    try {
      await ref.read(crmRepositoryProvider).patchFollowup(
            f.id,
            CrmFollowupPatch(
              scheduledAt: body.scheduledAt,
              activityTypeId: body.activityTypeId,
              priority: body.priority,
              notes: body.notes,
            ),
          );
      invalidateLeadDetail(ref, lead.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up updated')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    CrmFollowup f,
  ) async {
    final result = await showCompleteFollowupSheet(
      context,
      title: formatCrmDateTime(f.scheduledAt),
    );
    if (result == null) return;
    final repo = ref.read(crmRepositoryProvider);
    try {
      await repo.patchFollowup(
        f.id,
        CrmFollowupPatch(status: 'done', outcome: result.outcome),
      );
      if (result.nextAt != null) {
        await repo.createFollowup(
          CrmFollowupInput(
            leadId: f.leadId,
            activityTypeId: f.activityTypeId,
            scheduledAt: result.nextAt!.toUtc().toIso8601String(),
            priority: f.priority,
          ),
        );
      }
      invalidateLeadDetail(ref, lead.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.nextAt != null
                ? 'Completed — next follow-up scheduled'
                : 'Follow-up completed',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CrmFollowup f,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete follow-up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmRepositoryProvider).deleteFollowup(f.id);
      invalidateLeadDetail(ref, lead.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _actions(
    BuildContext context,
    WidgetRef ref,
    CrmFollowup f,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f.isPending && canUpdate)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Complete'),
                onTap: () {
                  Navigator.pop(ctx);
                  _complete(context, ref, f);
                },
              ),
            if (canUpdate)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(context, ref, f);
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(context, ref, f);
                },
              ),
          ],
        ),
      ),
    );
  }

  ContactBadgeTone _priorityTone(String p) => switch (p) {
        'high' => ContactBadgeTone.error,
        'low' => ContactBadgeTone.neutral,
        _ => ContactBadgeTone.secondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (canCreate)
          Row(
            children: [
              if (_hasOpen)
                Expanded(
                  child: Text(
                    'Complete the open follow-up before adding another',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const Spacer(),
              OutlinedButton(
                onPressed: _hasOpen ? null : () => _create(context, ref),
                child: const Text('New follow-up'),
              ),
            ],
          ),
        if (canCreate) const SizedBox(height: 12),
        if (followups.isEmpty)
          const CrmEmpty(message: 'No follow-ups scheduled.')
        else
          for (final f in followups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _actions(context, ref, f),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatCrmDateTime(f.scheduledAt),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ContactBadge(
                                label: f.status,
                                tone: f.isPending
                                    ? ContactBadgeTone.primary
                                    : ContactBadgeTone.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ContactBadge(
                                label: f.priority,
                                tone: _priorityTone(f.priority),
                              ),
                              if ((f.activityTypeName ?? '').isNotEmpty)
                                ContactBadge(
                                  label: f.activityTypeName!,
                                  tone: ContactBadgeTone.secondary,
                                ),
                              if ((f.assigneeName ?? '').isNotEmpty)
                                ContactBadge(
                                  label: f.assigneeName!,
                                  tone: ContactBadgeTone.tertiary,
                                ),
                            ],
                          ),
                          if (f.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              f.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
