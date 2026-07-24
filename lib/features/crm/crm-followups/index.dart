import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../profile/providers/profile_provider.dart';
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

  void _invalidate() {
    ref.invalidate(crmFollowupsProvider(''));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a lead first')),
      );
      return;
    }

    CrmFollowupInput? body;
    try {
      body = await showFollowupFormSheet(
        context,
        leads: leads,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up scheduled')),
      );
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

  Future<void> _edit(CrmFollowup f) async {
    final ui = ref.read(crmFollowupsUiProvider.notifier);
    ui.setFormSheetOpen(true);
    final config = await ref.read(crmConfigProvider.future);
    if (!mounted) {
      ui.setFormSheetOpen(false);
      return;
    }

    CrmFollowupInput? body;
    try {
      body = await showFollowupFormSheet(
        context,
        lead: leadStubFromFollowup(f),
        activityTypes: config.activityTypes,
        initial: f,
      );
    } finally {
      ui.setFormSheetOpen(false);
    }
    if (body == null || !mounted) return;

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
      _invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _complete(CrmFollowup f) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _delete(CrmFollowup f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete follow-up?'),
        content: Text(
          AppTranslations.translate(context, ref, 'crm_delete_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTranslations.translate(context, ref, 'cancel')),
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
      _invalidate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _actions(CrmFollowup f, bool canUpdate, bool canDelete) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open lead'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/crm/leads/${f.leadId}');
              },
            ),
            if (f.isPending && canUpdate)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Complete'),
                onTap: () {
                  Navigator.pop(ctx);
                  _complete(f);
                },
              ),
            if (canUpdate)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(f);
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
                  _delete(f);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _syncShellMeta(List<CrmFollowup> all, String myId, bool canCreate) {
    final mine = all.where((f) => isMineFollowup(f, myId)).length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(crmFollowupsUiProvider.notifier).syncMeta(
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
    final bySchedule =
        scoped.where((f) => matchesFollowupSchedule(f, ui.schedule));
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
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final perms = ref.watch(crmPermsProvider);
    final ui = ref.watch(crmFollowupsUiProvider);
    final async = ref.watch(crmFollowupsProvider(''));
    final myId = ref.watch(profileProvider).valueOrNull?.id ?? '';

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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/crm'),
        ),
        title: Text(AppTranslations.translate(context, ref, 'crm_followups')),
        actions: [
          if (ui.searchQuery.isNotEmpty)
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
                            onTap: () =>
                                _actions(f, perms.update, perms.delete),
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
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
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
