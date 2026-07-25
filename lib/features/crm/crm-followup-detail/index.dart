import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/providers/team_gate_provider.dart';
import '../crm-lead-detail/complete_followup_sheet.dart';
import '../crm-lead-detail/documents_tab.dart';
import '../crm-lead-detail/followup_form_sheet.dart';
import '../crm-lead-detail/stage_stepper.dart';
import '../crm-lead-detail/timeline_tab.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_followups_provider.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';
import 'contact_summary.dart';
import 'detail_header.dart';
import 'details_panel.dart';
import 'side_cards.dart';

/// Follow-up detail — web parity (summary + stepper + tabs + side cards).
class CrmFollowupDetailPage extends ConsumerStatefulWidget {
  const CrmFollowupDetailPage({super.key, required this.followupId});

  final String followupId;

  @override
  ConsumerState<CrmFollowupDetailPage> createState() =>
      _CrmFollowupDetailPageState();
}

class _CrmFollowupDetailPageState extends ConsumerState<CrmFollowupDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  CrmFollowup? _find(List<CrmFollowup> all) {
    for (final f in all) {
      if (f.id == widget.followupId) return f;
    }
    return null;
  }

  Future<void> _edit(CrmFollowup f, CrmLead lead, CrmConfig config) async {
    final stages = stagesForLead(lead, config);
    final body = await showFollowupFormSheet(
      context,
      lead: lead,
      config: config,
      stages: stages,
      activityTypes: config.activityTypes,
      initial: f,
    );
    if (body == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(crmRepositoryProvider)
          .patchFollowup(
            f.id,
            CrmFollowupPatch(
              scheduledAt: body.scheduledAt,
              stageId: body.stageId,
              activityTypeId: body.activityTypeId,
              priority: body.priority,
              notes: body.notes,
            ),
          );
      ref.invalidate(crmFollowupsProvider(''));
      invalidateLeadDetail(ref, f.leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follow-up updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
            stageId: f.stageId,
            activityTypeId: f.activityTypeId,
            scheduledAt: result.nextAt!.toUtc().toIso8601String(),
            priority: f.priority,
          ),
        );
      }
      ref.invalidate(crmFollowupsProvider(''));
      invalidateLeadDetail(ref, f.leadId);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CrmFollowup f) async {
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
    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).deleteFollowup(f.id);
      ref.invalidate(crmFollowupsProvider(''));
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/crm/followups');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _tabBody({
    required int index,
    required CrmLead lead,
    required CrmFollowup f,
    required String currency,
    required List<CrmTimelineEvent> timeline,
    required List<CrmNote> notes,
    required List<CrmActivity> activities,
    required List<CrmFollowup> leadFollowups,
    required List<CrmDocument> documents,
    required bool canCreate,
    required bool canDelete,
  }) {
    final colors = Theme.of(context).colorScheme;
    switch (index) {
      case 0:
        return TimelineTab(events: timeline, shrinkWrap: true);
      case 1:
        return FollowupDetailsPanel(
          lead: lead,
          followup: f,
          currency: currency,
        );
      case 2:
        if (notes.isEmpty) return const CrmEmpty(message: 'No notes yet');
        return Column(
          children: [
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body),
                        if ((n.authorName ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              n.authorName!,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadFollowups.isEmpty)
              const CrmEmpty(message: 'No tasks')
            else
              for (final t in leadFollowups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatCrmDateTime(t.scheduledAt)),
                  subtitle: Text(
                    [
                      t.status,
                      if ((t.activityTypeName ?? '').isNotEmpty)
                        t.activityTypeName!,
                    ].join(' · '),
                  ),
                  trailing: t.id == f.id
                      ? const Icon(Icons.place_outlined)
                      : null,
                  onTap: t.id == f.id
                      ? null
                      : () => context.push('/crm/followups/${t.id}'),
                ),
            if (activities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Logged activities',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final a in activities)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    a.subject.isEmpty
                        ? (a.activityTypeName ?? 'Activity')
                        : a.subject,
                  ),
                  subtitle: Text(
                    a.body.isEmpty ? formatCrmDateTime(a.occurredAt) : a.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ],
        );
      default:
        return DocumentsTab(
          leadId: lead.id,
          documents: documents,
          canCreate: canCreate,
          canDelete: canDelete,
          shrinkWrap: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crmFollowupsProvider(''));
    final configAsync = ref.watch(crmConfigProvider);
    final perms = ref.watch(crmPermsProvider);
    final colors = Theme.of(context).colorScheme;

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

        final leadAsync = ref.watch(crmLeadProvider(f.leadId));
        final config = configAsync.valueOrNull;

        return leadAsync.when(
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
          data: (lead) {
            final stages = stagesForLead(lead, config);
            final currency = config?.settings.currency ?? 'BDT';
            final timeline =
                ref.watch(crmLeadTimelineProvider(lead.id)).valueOrNull ??
                const [];
            final notes =
                ref.watch(crmLeadNotesProvider(lead.id)).valueOrNull ??
                const [];
            final activities =
                ref.watch(crmLeadActivitiesProvider(lead.id)).valueOrNull ??
                const [];
            final leadFollowups =
                ref.watch(crmLeadFollowupsProvider(lead.id)).valueOrNull ??
                const [];
            final documents =
                ref.watch(crmLeadDocumentsProvider(lead.id)).valueOrNull ??
                const [];
            final pendingTasks = leadFollowups.where((x) => x.isPending).length;

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
                  if (perms.delete)
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: _busy ? null : () => _delete(f),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              body: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      FollowupDetailHeader(
                        followup: f,
                        canEdit: perms.update && f.isPending && !_busy,
                        canComplete: perms.update && f.isPending && !_busy,
                        onEdit: () {
                          if (config == null) return;
                          _edit(f, lead, config);
                        },
                        onComplete: () => _complete(f),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            FollowupContactSummary(lead: lead, followup: f),
                            Divider(
                              height: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            LeadStageStepper(
                              lead: lead,
                              stages: stages,
                              events: timeline,
                              canEdit: perms.update,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FollowupSideCards(
                        lead: lead,
                        followup: f,
                        notes: notes,
                        leadFollowups: leadFollowups,
                        onEdit: perms.update && f.isPending && config != null
                            ? () => _edit(f, lead, config)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabs,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              tabs: [
                                const Tab(text: 'Timeline'),
                                const Tab(text: 'Details'),
                                Tab(text: 'Notes (${notes.length})'),
                                Tab(text: 'Tasks ($pendingTasks)'),
                                Tab(text: 'Documents (${documents.length})'),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              child: _tabBody(
                                index: _tabs.index,
                                lead: lead,
                                f: f,
                                currency: currency,
                                timeline: timeline,
                                notes: notes,
                                activities: activities,
                                leadFollowups: leadFollowups,
                                documents: documents,
                                canCreate: perms.create,
                                canDelete: perms.delete,
                              ),
                            ),
                          ],
                        ),
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
      },
    );
  }
}
