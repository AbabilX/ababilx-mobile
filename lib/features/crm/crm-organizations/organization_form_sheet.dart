import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/friendly_error.dart';
import '../../team/data/models/team_models.dart';
import '../crm-contacts/contact_avatar.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';

class OrganizationFormResult {
  const OrganizationFormResult({
    required this.organization,
    this.contacts = const [],
  });

  final CrmOrganizationInput organization;
  final List<CrmContactInput> contacts;
}

Future<OrganizationFormResult?> showOrganizationFormSheet(
  BuildContext context, {
  required List<TeamMember> members,
  required bool canAssignOwner,
  required bool canCreateContact,
  CrmOrganization? initial,
}) {
  return showModalBottomSheet<OrganizationFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: _OrganizationForm(
        members: members.where((m) => m.status == 'active').toList(),
        canAssignOwner: canAssignOwner,
        canCreateContact: canCreateContact,
        initial: initial,
      ),
    ),
  );
}

class _OrganizationForm extends ConsumerStatefulWidget {
  const _OrganizationForm({
    required this.members,
    required this.canAssignOwner,
    required this.canCreateContact,
    this.initial,
  });

  final List<TeamMember> members;
  final bool canAssignOwner;
  final bool canCreateContact;
  final CrmOrganization? initial;

  @override
  ConsumerState<_OrganizationForm> createState() => _OrganizationFormState();
}

class _OrganizationFormState extends ConsumerState<_OrganizationForm> {
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
  late String _logoUrl;
  final _contacts = <_ContactDraft>[];
  var _uploadingLogo = false;

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
    _logoUrl = value?.logoUrl ?? '';
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
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    if (_contacts.any(
      (contact) =>
          contact.name.text.trim().isNotEmpty &&
          contact.phone.text.trim().isEmpty,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone is required for every contact')),
      );
      return;
    }
    Navigator.pop(
      context,
      OrganizationFormResult(
        organization: CrmOrganizationInput(
          name: _name.text.trim(),
          ownerUserId: _ownerId,
          logoUrl: _logoUrl,
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
        contacts: [
          for (final contact in _contacts)
            if (contact.name.text.trim().isNotEmpty)
              CrmContactInput(
                name: contact.name.text.trim(),
                designation: contact.designation.text.trim(),
                email: contact.email.text.trim(),
                phone: contact.phone.text.trim(),
                isPrimaryContact: contact.isPrimary,
              ),
        ],
      ),
    );
  }

  void _addContact() => setState(() => _contacts.add(_ContactDraft()));

  Future<void> _pickLogo(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image exceeds 5 MB')));
      }
      return;
    }
    final mime = file.mimeType ?? _imageMimeType(file.path);
    setState(() => _uploadingLogo = true);
    try {
      final previous = _logoUrl;
      final url = await ref
          .read(crmRepositoryProvider)
          .uploadContactImage(
            bytes: Uint8List.fromList(bytes),
            contentType: mime,
          );
      if (previous.isNotEmpty && previous != url) {
        try {
          await ref.read(crmRepositoryProvider).discardContactImage(previous);
        } catch (_) {}
      }
      if (mounted) setState(() => _logoUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    final previous = _logoUrl;
    setState(() => _logoUrl = '');
    if (previous.isEmpty) return;
    try {
      await ref.read(crmRepositoryProvider).discardContactImage(previous);
    } catch (_) {}
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
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ContactAvatar(
                          name: _name.text.trim().isEmpty
                              ? '?'
                              : _name.text.trim(),
                          imageUrl: _logoUrl,
                          radius: 40,
                        ),
                        if (_uploadingLogo)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: colors.scrim.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _uploadingLogo
                              ? null
                              : () => _pickLogo(ImageSource.camera),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: const Text('Camera'),
                        ),
                        TextButton.icon(
                          onPressed: _uploadingLogo
                              ? null
                              : () => _pickLogo(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: Text(_logoUrl.isEmpty ? 'Gallery' : 'Change'),
                        ),
                        if (_logoUrl.isNotEmpty)
                          TextButton(
                            onPressed: _uploadingLogo ? null : _removeLogo,
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                autofocus: widget.initial == null,
                onChanged: (_) => setState(() {}),
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
              if (widget.initial == null && widget.canCreateContact) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contacts',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addContact,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add contact'),
                    ),
                  ],
                ),
                Text(
                  'Create people for this organization now.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                for (var index = 0; index < _contacts.length; index++)
                  _ContactDraftFields(
                    draft: _contacts[index],
                    onPrimaryChanged: (value) => setState(() {
                      for (final item in _contacts) {
                        item.isPrimary =
                            value && identical(item, _contacts[index]);
                      }
                    }),
                    onRemove: () => setState(() {
                      final draft = _contacts.removeAt(index);
                      draft.dispose();
                    }),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _imageMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class _ContactDraft {
  final name = TextEditingController();
  final designation = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  var isPrimary = false;

  void dispose() {
    name.dispose();
    designation.dispose();
    email.dispose();
    phone.dispose();
  }
}

class _ContactDraftFields extends StatelessWidget {
  const _ContactDraftFields({
    required this.draft,
    required this.onPrimaryChanged,
    required this.onRemove,
  });

  final _ContactDraft draft;
  final ValueChanged<bool> onPrimaryChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'New contact',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove contact',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            TextField(
              controller: draft.name,
              decoration: const InputDecoration(labelText: 'Full name *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.designation,
              decoration: const InputDecoration(labelText: 'Designation'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: draft.phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone *'),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.isPrimary,
              onChanged: (value) => onPrimaryChanged(value ?? false),
              title: const Text('Primary contact'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
}
