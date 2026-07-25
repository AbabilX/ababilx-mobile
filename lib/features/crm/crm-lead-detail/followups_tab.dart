import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crm-contacts/contact_badge.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';
import '../shared/stage_chip.dart';
import 'complete_followup_sheet.dart';
import 'followup_form_sheet.dart';

/// Lead follow-ups tab — stage chips + scoped create (web followups-tab).
class FollowupsTab extends ConsumerStatefulWidget {
  const FollowupsTab({
    super.key,
    required this.lead,
    required this.stages,
    required this.followups,
    required this.activityTypes,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
  });

  final CrmLead lead;
  final List<CrmStage> stages;
  final List<CrmFollowup> followups;
  final List<CrmActivityType> activityTypes;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;

  @override
  ConsumerState<FollowupsTab> createState() => _FollowupsTabState();
}

class _FollowupsTabState extends ConsumerState<FollowupsTab> {
  late String _filterStageId;

  @override
  void initState() {
    super.initState();
    _filterStageId = widget.lead.stageId ?? '';
  }

  @override
  void didUpdateWidget(covariant FollowupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lead.stageId != widget.lead.stageId &&
        (widget.lead.stageId ?? '').isNotEmpty) {
      _filterStageId = widget.lead.stageId!;
    }
  }

  List<CrmFollowup> get _filtered {
    if (_filterStageId.isEmpty) return widget.followups;
    return [
      for (final f in widget.followups)
        if (f.stageId == _filterStageId) f,
    ];
  }

  bool get _hasOpen => _filtered.any((f) => f.isPending);

  int _countFor(String stageId) {
    var n = 0;
    for (final f in widget.followups) {
      if (f.stageId == stageId) n++;
    }
    return n;
  }

  Future<void> _create() async {
    final body = await showFollowupFormSheet(
      context,
      lead: widget.lead,
      stages: widget.stages,
      fixedStageId: _filterStageId.isEmpty
          ? widget.lead.stageId
          : _filterStageId,
      activityTypes: widget.activityTypes,
    );
    if (body == null) return;
    try {
      await ref.read(crmRepositoryProvider).createFollowup(body);
      invalidateLeadDetail(ref, widget.lead.id);
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
    }
  }

  Future<void> _edit(CrmFollowup f) async {
    final body = await showFollowupFormSheet(
      context,
      lead: widget.lead,
      stages: widget.stages,
      initial: f,
      activityTypes: widget.activityTypes,
    );
    if (body == null) return;
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
      invalidateLeadDetail(ref, widget.lead.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follow-up updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
            stageId: f.stageId ?? widget.lead.stageId,
            activityTypeId: f.activityTypeId,
            scheduledAt: result.nextAt!.toUtc().toIso8601String(),
            priority: f.priority,
          ),
        );
      }
      invalidateLeadDetail(ref, widget.lead.id);
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
    try {
      await ref.read(crmRepositoryProvider).deleteFollowup(f.id);
      invalidateLeadDetail(ref, widget.lead.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _actions(CrmFollowup f) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f.isPending && widget.canUpdate)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Complete'),
                onTap: () {
                  Navigator.pop(ctx);
                  _complete(f);
                },
              ),
            if (widget.canUpdate)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit / reschedule'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(f);
                },
              ),
            if (widget.canDelete && f.isPending)
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

  ContactBadgeTone _priorityTone(String p) => switch (p) {
    'high' => ContactBadgeTone.error,
    'low' => ContactBadgeTone.neutral,
    _ => ContactBadgeTone.secondary,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final list = _filtered;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.stages.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in widget.stages)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _filterStageId == s.id,
                      label: Text(
                        '${s.name} (${_countFor(s.id)})'
                        '${s.id == widget.lead.stageId ? ' · Current' : ''}',
                      ),
                      onSelected: (_) => setState(() => _filterStageId = s.id),
                      avatar: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.canCreate)
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
                onPressed: _hasOpen ? null : _create,
                child: const Text('New follow-up'),
              ),
            ],
          ),
        if (widget.canCreate) const SizedBox(height: 12),
        if (list.isEmpty)
          const CrmEmpty(message: 'No follow-ups for this stage.')
        else
          for (final f in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _actions(f),
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
                              if ((f.stageName ?? '').isNotEmpty)
                                StageChip(
                                  name: f.stageName!,
                                  colorHex: f.stageColor,
                                ),
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
