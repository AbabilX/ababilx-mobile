import 'package:flutter/material.dart';

import '../../team/data/models/team_models.dart';
import '../data/models/crm_models.dart';

const _noneOwner = '__none__';

/// Create/edit contact bottom sheet — theme colors only.
Future<CrmContactInput?> showContactFormSheet(
  BuildContext context, {
  required CrmConfig config,
  required List<TeamMember> members,
  required String contactLabel,
  required bool canAssignOwner,
  CrmContact? initial,
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<CrmContactInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _ContactFormBody(
        config: config,
        members: members.where((m) => m.status == 'active').toList(),
        contactLabel: contactLabel,
        canAssignOwner: canAssignOwner,
        initial: initial,
      ),
    ),
  );
}

class _ContactFormBody extends StatefulWidget {
  const _ContactFormBody({
    required this.config,
    required this.members,
    required this.contactLabel,
    required this.canAssignOwner,
    this.initial,
  });

  final CrmConfig config;
  final List<TeamMember> members;
  final String contactLabel;
  final bool canAssignOwner;
  final CrmContact? initial;

  @override
  State<_ContactFormBody> createState() => _ContactFormBodyState();
}

class _ContactFormBodyState extends State<_ContactFormBody> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _company;
  late final TextEditingController _source;
  late final TextEditingController _tags;
  late String _ownerId;
  late Map<String, dynamic> _custom;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _email = TextEditingController(text: i?.email ?? '');
    _phone = TextEditingController(text: i?.phone ?? '');
    _company = TextEditingController(text: i?.company ?? '');
    _source = TextEditingController(text: i?.source ?? '');
    _tags = TextEditingController(text: (i?.tags ?? []).join(', '));
    _ownerId = i?.ownerUserId ?? _noneOwner;
    _custom = Map<String, dynamic>.from(i?.customFields ?? {});
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    _source.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      CrmContactInput(
        name: name,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        company: _company.text.trim(),
        source: _source.text.trim(),
        tags: tags,
        ownerUserId: _ownerId == _noneOwner ? null : _ownerId,
        unassignedOwner: widget.canAssignOwner && _ownerId == _noneOwner,
        customFields: _custom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final editing = widget.initial != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              editing
                  ? 'Edit ${widget.contactLabel}'
                  : 'New ${widget.contactLabel}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _company,
              decoration: const InputDecoration(
                labelText: 'Company',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Source',
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
                    value: _noneOwner,
                    child: Text('Unassigned'),
                  ),
                  for (final m in widget.members)
                    DropdownMenuItem(
                      value: m.userId,
                      child: Text(m.displayName),
                    ),
                ],
                onChanged: (v) => setState(() => _ownerId = v ?? _noneOwner),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'comma, separated',
                isDense: true,
              ),
            ),
            for (final f in widget.config.fields) ...[
              const SizedBox(height: 12),
              _CustomField(
                def: f,
                value: _custom[f.key],
                onChanged: (v) => setState(() => _custom[f.key] = v),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(editing ? 'Save' : 'Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomField extends StatelessWidget {
  const _CustomField({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  final CrmFieldDef def;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = def.required ? '${def.label} *' : def.label;
    final str = value == null ? '' : value.toString();

    if (def.type == 'checkbox') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value == true,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    if (def.type == 'select') {
      return DropdownButtonFormField<String>(
        key: ValueKey(str.isEmpty ? _noneOwner : str),
        initialValue: str.isEmpty ? _noneOwner : str,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem(value: _noneOwner, child: Text('None')),
          for (final o in def.options)
            DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => onChanged(v == _noneOwner ? '' : (v ?? '')),
      );
    }

    return TextFormField(
      initialValue: str,
      onChanged: onChanged,
      keyboardType: def.type == 'number'
          ? TextInputType.number
          : def.type == 'email'
              ? TextInputType.emailAddress
              : TextInputType.text,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
