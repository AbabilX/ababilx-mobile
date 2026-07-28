import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../team/data/models/team_models.dart';
import '../crm-lead-detail/complete_followup_sheet.dart';
import '../crm-lead-detail/followup_form_sheet.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_contacts_provider.dart';
import '../providers/crm_followups_provider.dart';
import '../providers/crm_followups_ui_provider.dart';
import '../providers/crm_leads_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';
import '../shared/followup_buckets.dart';
import 'export_followups.dart';
import 'followup_action_sheet.dart';
import 'followup_row.dart';

/// Follow-ups list — bar: [My|Add|All] + search; in-page schedule chips.
class CrmFollowupsPage extends ConsumerStatefulWidget {
  const CrmFollowupsPage({super.key});

  @override
  ConsumerState<CrmFollowupsPage> createState() => _CrmFollowupsPageState();
}

class _CrmFollowupsPageState extends ConsumerState<CrmFollowupsPage> {
  var _busy = false;
  var _lastAddTick = 0;
  var _selecting = false;
  final _selected = <String>{};

  void _invalidate() {
    ref.invalidate(crmFollowupsProvider(''));
  }

  void _clearSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<T?> _withShellSheetHidden<T>(Future<T?> Function() show) async {
    final ui = ref.read(crmFollowupsUiProvider.notifier);
    final alreadyOpen = ref.read(crmFollowupsUiProvider).formSheetOpen;
    if (!alreadyOpen) ui.setFormSheetOpen(true);
    try {
      return await show();
    } finally {
      if (!alreadyOpen) ui.setFormSheetOpen(false);
    }
  }

  Future<void> _openActionSheet(CrmFollowup f) async {
    final perms = ref.read(crmPermsProvider);
    final ui = ref.read(crmFollowupsUiProvider.notifier);
    ui.setFormSheetOpen(true);
    try {
      final action = await showFollowupActionSheet(
        context,
        followup: f,
        canUpdate: perms.update,
        canDelete: perms.delete,
      );
      if (!mounted || action == null) return;
      switch (action) {
        case FollowupSheetAction.complete:
          await _completeFollowup(f);
        case FollowupSheetAction.edit:
          await _editFollowup(f);
        case FollowupSheetAction.delete:
          await _deleteFollowup(f);
        case FollowupSheetAction.openDetail:
          await context.push('/crm/followups/${f.id}');
      }
    } finally {
      ui.setFormSheetOpen(false);
    }
  }

  Future<void> _openCreate() async {
    final ui = ref.read(crmFollowupsUiProvider.notifier);
    ui.setFormSheetOpen(true);

    final config = await ref.read(crmConfigProvider.future);
    List<CrmLead> leads = const [];
    try {
      leads = await ref.read(crmLeadsProvider('').future);
    } catch (_) {}

    if (!mounted) {
      ui.setFormSheetOpen(false);
      return;
    }
    if (leads.isEmpty) {
      ui.setFormSheetOpen(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create a lead first')));
      return;
    }

    CrmFollowupInput? body;
    try {
      body = await showFollowupFormSheet(
        context,
        leads: leads,
        config: config,
        activityTypes: config.activityTypes,
      );
    } finally {
      ui.setFormSheetOpen(false);
    }
    if (body == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).createFollowup(body);
      _invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follow-up scheduled')));
    } catch (e) {
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv(List<CrmFollowup> visible) async {
    if (visible.isEmpty) return;
    final csv = buildFollowupsCsv(visible);
    await SharePlus.instance.share(
      ShareParams(text: csv, subject: 'follow-ups.csv'),
    );
  }

  Future<void> _bulk(String action, {String? assignedUserId}) async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final n = await ref
          .read(crmRepositoryProvider)
          .bulkFollowups(
            ids: _selected.toList(),
            action: action,
            assignedUserId: assignedUserId,
          );
      _invalidate();
      _clearSelection();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$n updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkReassign(List<TeamMember> members) async {
    final active = members.where((m) => m.status == 'active').toList();
    if (active.isEmpty) return;
    final userId = await _withShellSheetHidden(
      () => showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Reassign to',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final m in active)
                ListTile(
                  title: Text(m.displayName),
                  onTap: () => Navigator.pop(ctx, m.userId),
                ),
            ],
          ),
        ),
      ),
    );
    if (userId == null) return;
    await _bulk('reassign', assignedUserId: userId);
  }

  List<CrmStage> _stagesForLead(CrmLead lead, CrmConfig config) {
    for (final p in config.pipelines) {
      if (p.id == lead.pipelineId) return p.stages;
    }
    return config.defaultPipeline?.stages ?? const [];
  }

  Future<void> _editFollowup(CrmFollowup f) async {
    final config = await ref.read(crmConfigProvider.future);
    CrmLead? lead;
    try {
      lead = await ref.read(crmRepositoryProvider).getLead(f.leadId);
    } catch (_) {}
    if (!mounted) return;
    final stages = lead == null
        ? const <CrmStage>[]
        : _stagesForLead(lead, config);
    final body = await _withShellSheetHidden(
      () => showFollowupFormSheet(
        context,
        lead: lead ?? leadStubFromFollowup(f),
        config: config,
        stages: stages,
        activityTypes: config.activityTypes,
        initial: f,
      ),
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
      _invalidate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeFollowup(CrmFollowup f) async {
    final result = await _withShellSheetHidden(
      () => showCompleteFollowupSheet(
        context,
        title: formatCrmDateTime(f.scheduledAt),
      ),
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
      _invalidate();
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

  Future<void> _deleteFollowup(CrmFollowup f) async {
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
      _invalidate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _syncShellMeta(List<CrmFollowup> all, String myId, bool canCreate) {
    final mine = all.where((f) => isMineFollowup(f, myId)).length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(crmFollowupsUiProvider.notifier)
          .syncMeta(
            mineCount: mine,
            allCount: all.length,
            canCreate: canCreate,
          );
    });
  }

  List<CrmFollowup> _visible(
    List<CrmFollowup> all,
    CrmFollowupsUiState ui,
    String myId,
  ) {
    final mine = all.where((f) => isMineFollowup(f, myId));
    final scoped = ui.scope == FollowupScope.mine ? mine : all;
    final bySchedule = scoped.where(
      (f) => matchesFollowupSchedule(f, ui.schedule),
    );
    final q = ui.searchQuery.toLowerCase();
    if (q.isEmpty) {
      return bySchedule.toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }
    return bySchedule.where((f) {
      return (f.contactName ?? '').toLowerCase().contains(q) ||
          (f.contactCompany ?? '').toLowerCase().contains(q) ||
          (f.contactPhone ?? '').toLowerCase().contains(q) ||
          (f.assigneeName ?? '').toLowerCase().contains(q);
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final perms = ref.watch(crmPermsProvider);
    final detail = ref.watch(teamGateProvider).valueOrNull;
    final ui = ref.watch(crmFollowupsUiProvider);
    final async = ref.watch(crmFollowupsProvider(''));
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';
    final canReassign = (detail?.canAssignCrmOwner ?? false) && perms.update;

    ref.listen(crmFollowupsUiProvider, (prev, next) {
      if (next.addTick != _lastAddTick &&
          (prev == null || next.addTick > prev.addTick)) {
        _lastAddTick = next.addTick;
        if (next.canCreate && !_busy) _openCreate();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            _selecting ? Icons.close_rounded : Icons.arrow_back_rounded,
          ),
          onPressed: () {
            if (_selecting) {
              _clearSelection();
            } else {
              context.go('/crm');
            }
          },
        ),
        title: Text(
          _selecting
              ? '${_selected.length} selected'
              : AppTranslations.translate(context, ref, 'crm_followups'),
        ),
        actions: [
          if (!_selecting)
            IconButton(
              tooltip: 'Export CSV',
              onPressed: () {
                final all = async.valueOrNull ?? const <CrmFollowup>[];
                _exportCsv(_visible(all, ui, myId));
              },
              icon: const Icon(Icons.download_rounded),
            ),
          if (!_selecting && (perms.update || perms.delete))
            IconButton(
              tooltip: 'Select',
              onPressed: () => setState(() => _selecting = true),
              icon: const Icon(Icons.checklist_rounded),
            ),
          if (ui.searchQuery.isNotEmpty && !_selecting)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () =>
                  ref.read(crmFollowupsUiProvider.notifier).setSearchQuery(''),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final s in FollowupSchedule.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_scheduleLabel(s)),
                          selected: ui.schedule == s,
                          onSelected: (_) => ref
                              .read(crmFollowupsUiProvider.notifier)
                              .setSchedule(s),
                        ),
                      ),
                  ],
                ),
              ),
              if (_selecting && _selected.isNotEmpty)
                Material(
                  color: colors.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        if (perms.update)
                          TextButton(
                            onPressed: () => _bulk('complete'),
                            child: const Text('Complete'),
                          ),
                        if (canReassign)
                          TextButton(
                            onPressed: () =>
                                _bulkReassign(detail?.members ?? const []),
                            child: const Text('Reassign'),
                          ),
                        if (perms.delete)
                          TextButton(
                            onPressed: () => _bulk('delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _clearSelection,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: async.when(
                  loading: () => const CrmLoading(),
                  error: (e, _) => CrmErrorBox(message: e.toString()),
                  data: (all) {
                    _syncShellMeta(all, myId, perms.create);
                    final visible = _visible(all, ui, myId);
                    if (visible.isEmpty) {
                      return CrmEmpty(
                        message: AppTranslations.translate(
                          context,
                          ref,
                          'crm_followups_empty',
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _invalidate(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          ShellPillMetrics.contentBottomInset,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final f = visible[i];
                          return FollowupRow(
                            followup: f,
                            selecting: _selecting,
                            selected: _selected.contains(f.id),
                            showMenu: perms.update || perms.delete,
                            onToggleSelect: (v) {
                              setState(() {
                                if (v) {
                                  _selected.add(f.id);
                                } else {
                                  _selected.remove(f.id);
                                }
                              });
                            },
                            onLongPress: () {
                              setState(() {
                                _selecting = true;
                                _selected.add(f.id);
                              });
                            },
                            onTap: () => _openActionSheet(f),
                            onMenu: () => _openActionSheet(f),
                          );
                        },
                      ),
                    );
                  },
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
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ],
      ),
    );
  }

  String _scheduleLabel(FollowupSchedule s) => switch (s) {
    FollowupSchedule.all => 'All',
    FollowupSchedule.today => 'Today',
    FollowupSchedule.overdue => 'Overdue',
    FollowupSchedule.tomorrow => 'Tomorrow',
    FollowupSchedule.week => 'This week',
    FollowupSchedule.completed => 'Completed',
  };
}
