import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/providers/team_gate_provider.dart';
import '../crm-leads/lead_form_sheet.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../crm-contacts/contact_badge.dart';
import '../shared/crm_money.dart';
import '../shared/crm_ui.dart';
import 'activities_tab.dart';
import 'documents_tab.dart';
import 'followups_tab.dart';
import 'notes_tab.dart';
import 'stage_select.dart';
import 'stage_stepper.dart';
import 'timeline_tab.dart';

/// Lead detail — header, stage stepper, 5 tabs (web parity).
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
    _tabs = TabController(length: 5, vsync: this);
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

  String? _pipelineName(CrmLead lead, CrmConfig? config) {
    if ((lead.pipelineName ?? '').isNotEmpty) return lead.pipelineName;
    return _pipelineFor(lead, config)?.name;
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead updated')),
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
        final pipelineName = _pipelineName(lead, config);
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

        final meta = [
          if ((lead.contactCompany ?? '').isNotEmpty) lead.contactCompany!,
          if ((lead.contactEmail ?? '').isNotEmpty) lead.contactEmail!,
          if ((lead.contactPhone ?? '').isNotEmpty) lead.contactPhone!,
          if (lead.source.isNotEmpty) 'Source: ${lead.source}',
        ].join(' · ');

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/crm/leads');
                }
              },
            ),
            title: Text(
              lead.title.isEmpty ? (lead.contactName ?? 'Lead') : lead.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (perms.update)
                IconButton(
                  tooltip: 'Edit',
                  onPressed: _busy ? null : () => _edit(lead),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'Follow-ups'),
                Tab(text: 'Notes'),
                Tab(text: 'Activities'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          body: Column(
            children: [
              Material(
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((lead.contactName ?? '').isNotEmpty)
                        InkWell(
                          onTap: lead.contactId.isNotEmpty
                              ? () => context
                                  .push('/crm/contacts/${lead.contactId}')
                              : null,
                          child: Text(
                            lead.contactName!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: lead.contactId.isNotEmpty
                                  ? colors.primary
                                  : null,
                            ),
                          ),
                        ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if ((pipelineName ?? '').isNotEmpty)
                            ContactBadge(
                              label: pipelineName!,
                              tone: ContactBadgeTone.neutral,
                            ),
                          LeadStageSelect(
                            lead: lead,
                            stages: stages,
                            canEdit: perms.update,
                          ),
                          if (lead.dealValue > 0)
                            Text(
                              formatCrmMoney(lead.dealValue, currency),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.tertiary,
                              ),
                            ),
                        ],
                      ),
                      if ((lead.ownerName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Owner: ${lead.ownerName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                    TimelineTab(events: timeline),
                    FollowupsTab(
                      lead: lead,
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
