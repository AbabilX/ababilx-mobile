import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/friendly_error.dart';
import '../../../core/router/root_back.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../crm-leads/lead_form_sheet.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';
import 'activities_tab.dart';
import 'documents_tab.dart';
import 'followups_tab.dart';
import 'followup_form_sheet.dart';
import 'meta_copy_badges.dart';
import 'notes_tab.dart';
import 'payments_tab.dart';
import 'stage_select.dart';
import 'stage_stepper.dart';
import 'timeline_tab.dart';

/// Lead detail — the next action, current stage, and compact deal record.
class CrmLeadDetailPage extends ConsumerStatefulWidget {
  const CrmLeadDetailPage({super.key, required this.leadId});

  final String leadId;

  @override
  ConsumerState<CrmLeadDetailPage> createState() => _CrmLeadDetailPageState();
}

class _CrmLeadDetailPageState extends ConsumerState<CrmLeadDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  CrmPipeline? _pipelineFor(CrmLead lead, CrmConfig? config) {
    final pipelines = config?.pipelines ?? const <CrmPipeline>[];
    for (final p in pipelines) {
      if (p.id == lead.pipelineId) return p;
    }
    return config?.defaultPipeline;
  }

  List<CrmStage> _stagesFor(CrmLead lead, CrmConfig? config) =>
      _pipelineFor(lead, config)?.stages ?? const [];

  Future<void> _edit(CrmLead lead) async {
    final config = await ref.read(crmConfigProvider.future);
    final detail = ref.read(teamGateProvider).valueOrNull;
    if (!mounted || detail == null) return;

    final result = await showLeadFormSheet(
      context,
      config: config,
      members: detail.members,
      contacts: const [],
      canAssignOwner: detail.canAssignCrmOwner,
      canCreateContact: false,
      initial: lead,
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).updateLead(lead.id, result.lead);
      invalidateLeadDetail(ref, lead.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFollowup(
    CrmLead lead,
    List<CrmStage> stages,
    List<CrmActivityType> activityTypes,
  ) async {
    final body = await showFollowupFormSheet(
      context,
      lead: lead,
      stages: stages,
      fixedStageId: lead.stageId,
      activityTypes: activityTypes,
    );
    if (body == null || !mounted) return;
    try {
      await ref.read(crmRepositoryProvider).createFollowup(body);
      invalidateLeadDetail(ref, lead.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Follow-up scheduled')));
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.contains('open_followup')
                ? 'This lead already has an open follow-up'
                : friendlyErrorMessage(error),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(crmLeadProvider(widget.leadId));
    final configAsync = ref.watch(crmConfigProvider);
    final perms = ref.watch(crmPermsProvider);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

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
        final config = configAsync.valueOrNull;
        final stages = _stagesFor(lead, config);
        final currency = config?.settings.currency ?? 'BDT';
        final timeline =
            ref.watch(crmLeadTimelineProvider(widget.leadId)).valueOrNull ??
            const [];
        final notes =
            ref.watch(crmLeadNotesProvider(widget.leadId)).valueOrNull ??
            const [];
        final activities =
            ref.watch(crmLeadActivitiesProvider(widget.leadId)).valueOrNull ??
            const [];
        final followups =
            ref.watch(crmLeadFollowupsProvider(widget.leadId)).valueOrNull ??
            const [];
        final documents =
            ref.watch(crmLeadDocumentsProvider(widget.leadId)).valueOrNull ??
            const [];
        final payments =
            ref.watch(crmLeadPaymentsProvider(widget.leadId)).valueOrNull ??
            const <CrmLeadPayment>[];

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => popOrGoHome(context),
            ),
            title: Text(
              (lead.contactName ?? '').isNotEmpty
                  ? '← ${lead.contactName}'
                  : 'Lead',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'Follow-ups'),
                Tab(text: 'Notes'),
                Tab(text: 'Activities'),
                Tab(text: 'Payments'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          body: Column(
            children: [
              Material(
                color: colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              lead.title.isEmpty
                                  ? (lead.contactName ?? 'Lead')
                                  : lead.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LeadStageSelect(
                            lead: lead,
                            stages: stages,
                            canEdit: perms.update && !_busy,
                            onTransitionCompleted: () => _tabs.animateTo(0),
                          ),
                          if (perms.update)
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: _busy ? null : () => _edit(lead),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: MetaCopyBadges(
                              company: lead.contactCompany,
                              email: lead.contactEmail,
                              phone: lead.contactPhone,
                              source: lead.source,
                            ),
                          ),
                          if (lead.dealValue > 0 ||
                              (lead.ownerName ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (lead.dealValue > 0)
                                    Text(
                                      formatCrmMoney(lead.dealValue, currency),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colors.tertiary,
                                          ),
                                    ),
                                  if ((lead.ownerName ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Owner: ${lead.ownerName}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              LeadStageStepper(
                lead: lead,
                stages: stages,
                events: timeline,
                canEdit: perms.update,
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    TimelineTab(
                      events: timeline,
                      canAddFollowup: perms.create,
                      onAddFollowup: perms.create
                          ? () => _addFollowup(
                              lead,
                              stages,
                              config?.activityTypes ?? const [],
                            )
                          : null,
                    ),
                    FollowupsTab(
                      lead: lead,
                      stages: stages,
                      followups: followups,
                      activityTypes: config?.activityTypes ?? const [],
                      canCreate: perms.create,
                      canUpdate: perms.update,
                      canDelete: perms.delete,
                    ),
                    NotesTab(
                      leadId: lead.id,
                      notes: notes,
                      canCreate: perms.create,
                      canDelete: perms.delete,
                    ),
                    ActivitiesTab(
                      leadId: lead.id,
                      activities: activities,
                      activityTypes: config?.activityTypes ?? const [],
                      canCreate: perms.create,
                    ),
                    PaymentsTab(
                      lead: lead,
                      payments: payments,
                      currency: currency,
                      canCreate: perms.create,
                      canDelete: perms.delete,
                    ),
                    DocumentsTab(
                      leadId: lead.id,
                      documents: documents,
                      canCreate: perms.create,
                      canDelete: perms.delete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
