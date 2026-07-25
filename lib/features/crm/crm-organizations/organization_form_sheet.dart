import 'package:flutter/material.dart';

import '../../team/data/models/team_models.dart';
import '../data/models/crm_models.dart';

Future<CrmOrganizationInput?> showOrganizationFormSheet(
  BuildContext context, {
  required List<TeamMember> members,
  required bool canAssignOwner,
  CrmOrganization? initial,
}) {
  return showModalBottomSheet<CrmOrganizationInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: _OrganizationForm(
        members: members.where((m) => m.status == 'active').toList(),
        canAssignOwner: canAssignOwner,
        initial: initial,
      ),
    ),
  );
}

class _OrganizationForm extends StatefulWidget {
  const _OrganizationForm({
    required this.members,
    required this.canAssignOwner,
    this.initial,
  });

  final List<TeamMember> members;
  final bool canAssignOwner;
  final CrmOrganization? initial;

  @override
  State<_OrganizationForm> createState() => _OrganizationFormState();
}

class _OrganizationFormState extends State<_OrganizationForm> {
  late final TextEditingController _name;
  late final TextEditingController _website;
  late final TextEditingController _industry;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _source;
  late final TextEditingController _description;
  late final TextEditingController _brands;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _name = TextEditingController(text: value?.name ?? '');
    _website = TextEditingController(text: value?.website ?? '');
    _industry = TextEditingController(text: value?.industry ?? '');
    _email = TextEditingController(text: value?.email ?? '');
    _phone = TextEditingController(text: value?.phone ?? '');
    _address = TextEditingController(text: value?.address ?? '');
    _source = TextEditingController(text: value?.source ?? '');
    _description = TextEditingController(text: value?.description ?? '');
    _brands = TextEditingController(text: (value?.tags ?? []).join(', '));
    _ownerId = value?.ownerUserId;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _website,
      _industry,
      _email,
      _phone,
      _address,
      _source,
      _description,
      _brands,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      CrmOrganizationInput(
        name: _name.text.trim(),
        ownerUserId: _ownerId,
        logoUrl: widget.initial?.logoUrl ?? '',
        website: _website.text.trim(),
        industry: _industry.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        source: _source.text.trim(),
        description: _description.text.trim(),
        tags: _brands.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        customFields: widget.initial?.customFields ?? const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
                  widget.initial == null
                      ? 'New organization'
                      : 'Edit organization',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              TextField(
                controller: _name,
                autofocus: widget.initial == null,
                decoration: const InputDecoration(
                  labelText: 'Organization name *',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _website,
                      decoration: const InputDecoration(labelText: 'Website'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _industry,
                      decoration: const InputDecoration(labelText: 'Industry'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                decoration: const InputDecoration(labelText: 'Source'),
              ),
              if (widget.canAssignOwner) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ownerId ?? '',
                  decoration: const InputDecoration(labelText: 'Owner'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Unassigned'),
                    ),
                    for (final member in widget.members)
                      DropdownMenuItem(
                        value: member.userId,
                        child: Text(member.displayName),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _ownerId = value?.isEmpty == true ? null : value,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _brands,
                decoration: const InputDecoration(
                  labelText: 'Brands',
                  hintText: 'Type a brand, then comma',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
