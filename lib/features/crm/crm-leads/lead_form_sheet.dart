import 'package:flutter/material.dart';

import '../../team/data/models/team_models.dart';
import '../data/models/crm_models.dart';

const _none = '__none__';

/// Create/edit lead sheet — contact picker + deal fields (web LeadFormDialog).
Future<CrmLeadFormResult?> showLeadFormSheet(
  BuildContext context, {
  required CrmConfig config,
  required List<TeamMember> members,
  required List<CrmContact> contacts,
  required bool canAssignOwner,
  required bool canCreateContact,
  CrmLead? initial,
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<CrmLeadFormResult>(
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
        height: h * 0.92,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _LeadFormBody(
            config: config,
            members: members.where((m) => m.status == 'active').toList(),
            contacts: contacts,
            canAssignOwner: canAssignOwner,
            canCreateContact: canCreateContact,
            initial: initial,
          ),
        ),
      );
    },
  );
}

class _LeadFormBody extends StatefulWidget {
  const _LeadFormBody({
    required this.config,
    required this.members,
    required this.contacts,
    required this.canAssignOwner,
    required this.canCreateContact,
    this.initial,
  });

  final CrmConfig config;
  final List<TeamMember> members;
  final List<CrmContact> contacts;
  final bool canAssignOwner;
  final bool canCreateContact;
  final CrmLead? initial;

  @override
  State<_LeadFormBody> createState() => _LeadFormBodyState();
}

class _LeadFormBodyState extends State<_LeadFormBody> {
  late final TextEditingController _title;
  late final TextEditingController _dealValue;
  late final TextEditingController _source;
  late final TextEditingController _newName;
  late final TextEditingController _newPhone;

  late String _contactId;
  late String _pipelineId;
  late String _stageId;
  late String _ownerId;
  var _newContactMode = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final def = widget.config.defaultPipeline;
    _title = TextEditingController(text: i?.title ?? '');
    _dealValue = TextEditingController(
      text: (i != null && i.dealValue > 0) ? i.dealValue.toString() : '',
    );
    _source = TextEditingController(text: i?.source ?? '');
    _newName = TextEditingController();
    _newPhone = TextEditingController();
    _contactId = i?.contactId ?? '';
    _pipelineId = i?.pipelineId ?? def?.id ?? _none;
    final stages = _stagesFor(_pipelineId);
    _stageId = i?.stageId ??
        (stages.isNotEmpty ? stages.first.id : _none);
    _ownerId = i?.ownerUserId ?? _none;
  }

  @override
  void dispose() {
    _title.dispose();
    _dealValue.dispose();
    _source.dispose();
    _newName.dispose();
    _newPhone.dispose();
    super.dispose();
  }

  List<CrmStage> _stagesFor(String pipelineId) {
    for (final p in widget.config.pipelines) {
      if (p.id == pipelineId) return p.stages;
    }
    return const [];
  }

  bool get _canSave {
    if (_editing) return true;
    if (_newContactMode) return _newName.text.trim().isNotEmpty;
    return _contactId.isNotEmpty;
  }

  void _submit() {
    if (!_canSave) return;
    final deal = double.tryParse(_dealValue.text.trim()) ?? 0;
    final lead = CrmLeadInput(
      title: _title.text.trim(),
      pipelineId: _pipelineId == _none ? null : _pipelineId,
      stageId: _stageId == _none ? null : _stageId,
      dealValue: deal < 0 ? 0 : deal,
      source: _source.text.trim(),
      ownerUserId: _ownerId == _none ? null : _ownerId,
      unassignedOwner: widget.canAssignOwner && _ownerId == _none,
    );

    if (_editing) {
      Navigator.pop(
        context,
        CrmLeadFormResult(
          contactId: widget.initial!.contactId,
          lead: lead,
        ),
      );
      return;
    }

    if (_newContactMode) {
      Navigator.pop(
        context,
        CrmLeadFormResult(
          newContact: CrmContactInput(
            name: _newName.text.trim(),
            phone: _newPhone.text.trim(),
          ),
          lead: lead,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      CrmLeadFormResult(contactId: _contactId, lead: lead),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stages = _stagesFor(_pipelineId);
    final canSave = _canSave;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  _editing ? 'Edit lead' : 'New lead',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: canSave ? _submit : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: canSave ? colors.primary : colors.onSurfaceVariant,
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
              if (!_editing) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contact *',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    if (widget.canCreateContact)
                      TextButton(
                        onPressed: () => setState(() {
                          _newContactMode = !_newContactMode;
                        }),
                        child: Text(
                          _newContactMode ? 'Pick existing' : 'New contact',
                        ),
                      ),
                  ],
                ),
                if (_newContactMode) ...[
                  TextField(
                    controller: _newName,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      isDense: true,
                    ),
                  ),
                ] else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_contactId.isEmpty ? _none : _contactId),
                    initialValue: _contactId.isEmpty ? _none : _contactId,
                    decoration: const InputDecoration(
                      labelText: 'Contact',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: _none,
                        child: Text('Select contact'),
                      ),
                      for (final c in widget.contacts)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _contactId = (v == null || v == _none) ? '' : v;
                    }),
                  ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: "Defaults to the contact's name",
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_pipelineId),
                initialValue: _pipelineId,
                decoration: const InputDecoration(
                  labelText: 'Pipeline',
                  isDense: true,
                ),
                items: [
                  if (widget.config.pipelines.isEmpty)
                    const DropdownMenuItem(
                      value: _none,
                      child: Text('No pipeline'),
                    ),
                  for (final p in widget.config.pipelines)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final nextStages = _stagesFor(v);
                  setState(() {
                    _pipelineId = v;
                    _stageId =
                        nextStages.isNotEmpty ? nextStages.first.id : _none;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('$_pipelineId-$_stageId'),
                initialValue: stages.any((s) => s.id == _stageId)
                    ? _stageId
                    : (stages.isNotEmpty ? stages.first.id : _none),
                decoration: const InputDecoration(
                  labelText: 'Stage',
                  isDense: true,
                ),
                items: [
                  if (stages.isEmpty)
                    const DropdownMenuItem(
                      value: _none,
                      child: Text('No stage'),
                    ),
                  for (final s in stages)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: stages.isEmpty
                    ? null
                    : (v) => setState(() => _stageId = v ?? _none),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dealValue,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Deal value',
                  hintText: '0',
                  isDense: true,
                  prefixText:
                      widget.config.settings.currency == 'BDT' ? '৳ ' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'e.g. Referral',
                  isDense: true,
                ),
              ),
              if (widget.canAssignOwner) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_ownerId),
                  initialValue: _ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Owner',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _none,
                      child: Text('Unassigned'),
                    ),
                    for (final m in widget.members)
                      DropdownMenuItem(
                        value: m.userId,
                        child: Text(m.displayName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _ownerId = v ?? _none),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
