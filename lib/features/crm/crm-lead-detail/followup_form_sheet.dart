import 'package:flutter/material.dart';

import '../data/models/crm_models.dart';

const _none = '__none__';

/// Create/edit follow-up.
/// Pass [lead] to lock; or [leads] for picker (list page Add).
Future<CrmFollowupInput?> showFollowupFormSheet(
  BuildContext context, {
  CrmLead? lead,
  List<CrmLead>? leads,
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
        height: h * 0.8,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _FollowupFormBody(
            lead: lead,
            leads: leads ?? const [],
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
    required this.activityTypes,
    this.initial,
  });

  final CrmLead? lead;
  final List<CrmLead> leads;
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

  bool get _editing => widget.initial != null;
  bool get _leadLocked => widget.lead != null || _editing;

  CrmLead? get _selectedLead {
    if (widget.lead != null) return widget.lead;
    for (final l in widget.leads) {
      if (l.id == _leadId) return l;
    }
    return null;
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

  bool get _canSave => _leadId.isNotEmpty;

  void _submit() {
    if (!_canSave) return;
    Navigator.pop(
      context,
      CrmFollowupInput(
        leadId: _leadId,
        scheduledAt: _when.toUtc().toIso8601String(),
        activityTypeId: _typeId == _none ? null : _typeId,
        priority: _priority,
        notes: _notes.text.trim(),
        assignedUserId: widget.initial?.assignedUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selectedLead;

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
                  onChanged: (v) => setState(() {
                    _leadId = (v == null || v == _none) ? '' : v;
                  }),
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
