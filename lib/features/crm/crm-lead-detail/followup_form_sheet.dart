import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';
import '../shared/stage_chip.dart';

const _none = '__none__';

List<CrmStage> stagesForLead(CrmLead? lead, CrmConfig? config) {
  if (lead == null || config == null) return const [];
  for (final p in config.pipelines) {
    if (p.id == lead.pipelineId) return p.stages;
  }
  return config.defaultPipeline?.stages ?? const [];
}

/// Create/edit follow-up — stage required; locked on edit (web parity).
Future<CrmFollowupInput?> showFollowupFormSheet(
  BuildContext context, {
  CrmLead? lead,
  List<CrmLead>? leads,
  CrmConfig? config,
  List<CrmStage> stages = const [],
  String? fixedStageId,
  required List<CrmActivityType> activityTypes,
  CrmFollowup? initial,
}) {
  assert(
    lead != null || (leads != null && leads.isNotEmpty) || initial != null,
    'Need lead, leads, or initial',
  );
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<CrmFollowupInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        height: h * 0.85,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _FollowupFormBody(
            lead: lead,
            leads: leads ?? const [],
            config: config,
            stages: stages,
            fixedStageId: fixedStageId,
            activityTypes: activityTypes,
            initial: initial,
          ),
        ),
      );
    },
  );
}

class _FollowupFormBody extends StatefulWidget {
  const _FollowupFormBody({
    this.lead,
    required this.leads,
    this.config,
    required this.stages,
    this.fixedStageId,
    required this.activityTypes,
    this.initial,
  });

  final CrmLead? lead;
  final List<CrmLead> leads;
  final CrmConfig? config;
  final List<CrmStage> stages;
  final String? fixedStageId;
  final List<CrmActivityType> activityTypes;
  final CrmFollowup? initial;

  @override
  State<_FollowupFormBody> createState() => _FollowupFormBodyState();
}

class _FollowupFormBodyState extends State<_FollowupFormBody> {
  late final TextEditingController _notes;
  late DateTime _when;
  late String _typeId;
  late String _priority;
  late String _leadId;
  late String _stageId;

  bool get _editing => widget.initial != null;
  bool get _leadLocked => widget.lead != null || _editing;

  /// Web: `locked={fixedStageId || isEdit}`.
  bool get _stageLocked => (widget.fixedStageId ?? '').isNotEmpty || _editing;

  CrmLead? get _selectedLead {
    if (widget.lead != null) return widget.lead;
    for (final l in widget.leads) {
      if (l.id == _leadId) return l;
    }
    return null;
  }

  List<CrmStage> get _resolvedStages {
    if (widget.stages.isNotEmpty &&
        (widget.config == null || widget.lead != null)) {
      // Prefer explicit stages when lead is fixed.
      if (widget.lead != null || _editing) return widget.stages;
    }
    final fromConfig = stagesForLead(_selectedLead, widget.config);
    if (fromConfig.isNotEmpty) return fromConfig;
    return widget.stages;
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _notes = TextEditingController(text: i?.notes ?? '');
    _when = i != null
        ? (DateTime.tryParse(i.scheduledAt)?.toLocal() ??
              DateTime.now().add(const Duration(days: 1)))
        : DateTime.now().add(const Duration(hours: 24));
    _typeId = i?.activityTypeId ?? _none;
    _priority = i?.priority ?? 'medium';
    _leadId = i?.leadId ?? widget.lead?.id ?? '';
    final stages = _resolvedStages;
    _stageId =
        widget.fixedStageId ??
        i?.stageId ??
        widget.lead?.stageId ??
        (stages.isNotEmpty ? stages.first.id : '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t == null || !mounted) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  bool get _canSave => _leadId.isNotEmpty && _stageId.isNotEmpty;

  void _onLeadChanged(String? v) {
    final id = (v == null || v == _none) ? '' : v;
    setState(() {
      _leadId = id;
      final lead = _selectedLead;
      final stages = stagesForLead(lead, widget.config);
      if (lead?.stageId != null &&
          (stages.isEmpty || stages.any((s) => s.id == lead!.stageId))) {
        _stageId = lead!.stageId!;
      } else if (stages.isNotEmpty) {
        _stageId = stages.first.id;
      } else {
        _stageId = lead?.stageId ?? '';
      }
    });
  }

  void _submit() {
    if (!_canSave) return;
    Navigator.pop(
      context,
      CrmFollowupInput(
        leadId: _leadId,
        scheduledAt: _when.toUtc().toIso8601String(),
        stageId: _stageId,
        activityTypeId: _typeId == _none ? null : _typeId,
        priority: _priority,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selectedLead;
    final stages = _resolvedStages;
    CrmStage? lockedStage;
    for (final s in stages) {
      if (s.id == _stageId) {
        lockedStage = s;
        break;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  _editing ? 'Edit follow-up' : 'New follow-up',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _canSave ? _submit : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _canSave ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.5)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (_leadLocked) ...[
                Text(
                  selected?.title.isNotEmpty == true
                      ? selected!.title
                      : (selected?.contactName ??
                            widget.initial?.contactName ??
                            'Lead'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((selected?.ownerName ?? widget.initial?.assigneeName ?? '')
                    .isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Assigned to ${selected?.ownerName ?? widget.initial?.assigneeName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ] else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_leadId.isEmpty ? _none : _leadId),
                  initialValue: _leadId.isEmpty ? _none : _leadId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lead *',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _none,
                      child: Text('Select lead'),
                    ),
                    for (final l in widget.leads)
                      DropdownMenuItem(
                        value: l.id,
                        child: Text(
                          l.title.isNotEmpty
                              ? l.title
                              : (l.contactName ?? l.id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _onLeadChanged,
                ),
                if (selected != null &&
                    (selected.ownerName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Assigned to ${selected.ownerName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              if (_stageLocked && lockedStage != null)
                Row(
                  children: [
                    Text(
                      'Stage',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    StageChip(
                      name: lockedStage.name,
                      colorHex: lockedStage.color,
                    ),
                  ],
                )
              else if (stages.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey('stage-$_stageId-$_leadId'),
                  initialValue: _stageId.isEmpty ? null : _stageId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Stage *',
                    isDense: true,
                  ),
                  items: [
                    for (final s in stages)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _stageId = v ?? ''),
                )
              else
                Text(
                  'Select a lead to choose stage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('When *'),
                subtitle: Text(_when.toLocal().toString().substring(0, 16)),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(_typeId),
                initialValue: _typeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Activity type',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: _none, child: Text('None')),
                  for (final t in widget.activityTypes)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _typeId = v ?? _none),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_priority),
                initialValue: _priority,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
