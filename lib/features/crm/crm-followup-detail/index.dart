import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/providers/team_gate_provider.dart';
import '../crm-contacts/contact_badge.dart';
import '../crm-lead-detail/complete_followup_sheet.dart';
import '../crm-lead-detail/followup_form_sheet.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_followups_provider.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';
import '../shared/followup_buckets.dart';

/// Follow-up detail — meta + actions + open lead (web follow-up detail lite).
class CrmFollowupDetailPage extends ConsumerStatefulWidget {
  const CrmFollowupDetailPage({super.key, required this.followupId});

  final String followupId;

  @override
  ConsumerState<CrmFollowupDetailPage> createState() =>
      _CrmFollowupDetailPageState();
}

class _CrmFollowupDetailPageState extends ConsumerState<CrmFollowupDetailPage> {
  var _busy = false;

  CrmFollowup? _find(List<CrmFollowup> all) {
    for (final f in all) {
      if (f.id == widget.followupId) return f;
    }
    return null;
  }

  Future<void> _edit(CrmFollowup f) async {
    final config = await ref.read(crmConfigProvider.future);
    if (!mounted) return;
    final body = await showFollowupFormSheet(
      context,
      lead: leadStubFromFollowup(f),
      activityTypes: config.activityTypes,
      initial: f,
    );
    if (body == null || !mounted) return;
    setState(() => _busy = true);
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
      ref.invalidate(crmFollowupsProvider(''));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(CrmFollowup f) async {
    final result = await showCompleteFollowupSheet(
      context,
      title: formatCrmDateTime(f.scheduledAt),
    );
    if (result == null) return;
    final repo = ref.read(crmRepositoryProvider);
    setState(() => _busy = true);
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
      ref.invalidate(crmFollowupsProvider(''));
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ContactBadgeTone _statusTone(String label) => switch (label) {
        'Overdue' => ContactBadgeTone.error,
        'Completed' => ContactBadgeTone.tertiary,
        _ => ContactBadgeTone.primary,
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crmFollowupsProvider(''));
    final perms = ref.watch(crmPermsProvider);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const CrmLoading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: CrmErrorBox(message: e.toString()),
      ),
      data: (all) {
        final f = _find(all);
        if (f == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: const CrmEmpty(message: 'Follow-up not found.'),
          );
        }

        final status = followupStatusLabel(f);
        final leadAsync = ref.watch(crmLeadProvider(f.leadId));

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/crm/followups');
                }
              },
            ),
            title: const Text('Follow-up'),
            actions: [
              if (perms.update)
                IconButton(
                  tooltip: 'Edit',
                  onPressed: _busy ? null : () => _edit(f),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Row(
                    children: [
                      ContactBadge(
                        label: status,
                        tone: _statusTone(status),
                      ),
                      const SizedBox(width: 8),
                      ContactBadge(
                        label: f.priority,
                        tone: f.priority == 'high'
                            ? ContactBadgeTone.error
                            : ContactBadgeTone.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatCrmDateTime(f.scheduledAt),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MetaTile(
                    label: 'Contact',
                    value: f.contactName ?? '—',
                    onTap: f.contactId.isNotEmpty
                        ? () => context.push('/crm/contacts/${f.contactId}')
                        : null,
                  ),
                  if ((f.contactCompany ?? '').isNotEmpty)
                    _MetaTile(label: 'Company', value: f.contactCompany!),
                  if ((f.contactPhone ?? '').isNotEmpty)
                    _MetaTile(label: 'Phone', value: f.contactPhone!),
                  if ((f.activityTypeName ?? '').isNotEmpty)
                    _MetaTile(label: 'Type', value: f.activityTypeName!),
                  if ((f.assigneeName ?? '').isNotEmpty)
                    _MetaTile(label: 'Assignee', value: f.assigneeName!),
                  leadAsync.when(
                    data: (lead) => _MetaTile(
                      label: 'Lead',
                      value: lead.title.isNotEmpty
                          ? lead.title
                          : (lead.contactName ?? 'Lead'),
                      onTap: () => context.push('/crm/leads/${lead.id}'),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => _MetaTile(
                      label: 'Lead',
                      value: 'Open lead',
                      onTap: () => context.push('/crm/leads/${f.leadId}'),
                    ),
                  ),
                  if (f.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(f.notes, style: theme.textTheme.bodyMedium),
                  ],
                  if (f.outcome.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Outcome',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(f.outcome, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 24),
                  if (f.isPending && perms.update)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _complete(f),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/crm/leads/${f.leadId}'),
                    icon: const Icon(Icons.work_outline_rounded),
                    label: const Text('Open lead'),
                  ),
                ],
              ),
              if (_busy)
                ModalBarrier(
                  dismissible: false,
                  color: colors.scrim.withValues(alpha: 0.35),
                ),
              if (_busy)
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: onTap != null ? colors.primary : null,
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: colors.onSurfaceVariant)
          : null,
      onTap: onTap,
    );
  }
}
