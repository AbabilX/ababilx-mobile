import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../team/data/models/team_models.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import 'contact_avatar.dart';
import 'contact_type_label.dart';

const _noneOwner = '__none__';

/// Create/edit contact sheet — type, designation, image (web parity).
Future<CrmContactInput?> showContactFormSheet(
  BuildContext context, {
  required CrmConfig config,
  required List<TeamMember> members,
  required String contactLabel,
  required bool canAssignOwner,
  List<CrmOrganization> organizations = const [],
  CrmContact? initial,
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<CrmContactInput>(
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
          child: _ContactFormBody(
            config: config,
            members: members.where((m) => m.status == 'active').toList(),
            contactLabel: contactLabel,
            canAssignOwner: canAssignOwner,
            organizations: organizations,
            initial: initial,
          ),
        ),
      );
    },
  );
}

class _ContactFormBody extends ConsumerStatefulWidget {
  const _ContactFormBody({
    required this.config,
    required this.members,
    required this.contactLabel,
    required this.canAssignOwner,
    required this.organizations,
    this.initial,
  });

  final CrmConfig config;
  final List<TeamMember> members;
  final String contactLabel;
  final bool canAssignOwner;
  final List<CrmOrganization> organizations;
  final CrmContact? initial;

  @override
  ConsumerState<_ContactFormBody> createState() => _ContactFormBodyState();
}

class _ContactFormBodyState extends ConsumerState<_ContactFormBody> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _company;
  late final TextEditingController _designation;
  late final TextEditingController _source;
  late final TextEditingController _tags;
  late String _ownerId;
  late String _contactType;
  late String _imageUrl;
  String? _organizationId;
  late final TextEditingController _organizationRole;
  var _isPrimary = false;
  late Map<String, dynamic> _custom;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _email = TextEditingController(text: i?.email ?? '');
    _phone = TextEditingController(text: i?.phone ?? '');
    _company = TextEditingController(text: i?.company ?? '');
    _designation = TextEditingController(text: i?.designation ?? '');
    _source = TextEditingController(text: i?.source ?? '');
    _tags = TextEditingController(text: (i?.tags ?? []).join(', '));
    _ownerId = i?.ownerUserId ?? _noneOwner;
    _contactType = i?.contactType ?? 'contact';
    _imageUrl = i?.imageUrl ?? '';
    _organizationId = i?.organizationId;
    _organizationRole = TextEditingController(text: i?.organizationRole ?? '');
    _isPrimary = i?.isPrimaryContact ?? false;
    _custom = Map<String, dynamic>.from(i?.customFields ?? {});
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _company.dispose();
    _designation.dispose();
    _source.dispose();
    _tags.dispose();
    _organizationRole.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image exceeds 5 MB')));
      return;
    }

    final mime =
        file.mimeType ??
        (file.path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : file.path.toLowerCase().endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg');

    setState(() => _uploading = true);
    try {
      final prev = _imageUrl;
      final url = await ref
          .read(crmRepositoryProvider)
          .uploadContactImage(
            bytes: Uint8List.fromList(bytes),
            contentType: mime,
          );
      if (prev.isNotEmpty && prev != url) {
        try {
          await ref.read(crmRepositoryProvider).discardContactImage(prev);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _clearImage() async {
    final prev = _imageUrl;
    setState(() => _imageUrl = '');
    if (prev.isEmpty) return;
    try {
      await ref.read(crmRepositoryProvider).discardContactImage(prev);
    } catch (_) {}
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty || _phone.text.trim().isEmpty || _uploading) return;
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
        contactType: _contactType,
        designation: _designation.text.trim(),
        imageUrl: _imageUrl,
        source: _source.text.trim(),
        tags: tags,
        ownerUserId: _ownerId == _noneOwner ? null : _ownerId,
        organizationId: _organizationId,
        organizationRole: _organizationRole.text.trim(),
        isPrimaryContact: _isPrimary,
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
    final canSave =
        _name.text.trim().isNotEmpty &&
        _phone.text.trim().isNotEmpty &&
        !_uploading;

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
                  editing
                      ? 'Edit ${widget.contactLabel}'
                      : 'New ${widget.contactLabel}',
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
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ContactAvatar(
                          name: _name.text.isEmpty ? '?' : _name.text,
                          imageUrl: _imageUrl,
                          radius: 40,
                        ),
                        if (_uploading)
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
                          onPressed: _uploading
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: const Text('Camera'),
                        ),
                        TextButton.icon(
                          onPressed: _uploading
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: Text(_imageUrl.isEmpty ? 'Gallery' : 'Change'),
                        ),
                        if (_imageUrl.isNotEmpty)
                          TextButton(
                            onPressed: _uploading ? null : _clearImage,
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(_contactType),
                initialValue: _contactType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  isDense: true,
                ),
                items: [
                  for (final t in kCrmContactTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(contactTypeLabel(t)),
                    ),
                ],
                onChanged: (v) => setState(() => _contactType = v ?? 'contact'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _organizationId ?? _noneOwner,
                decoration: const InputDecoration(
                  labelText: 'Organization (optional)',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: _noneOwner,
                    child: Text('No organization'),
                  ),
                  for (final organization in widget.organizations)
                    DropdownMenuItem(
                      value: organization.id,
                      child: Text(organization.name),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _organizationId = value == _noneOwner ? null : value,
                ),
              ),
              if (_organizationId != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _organizationRole,
                  decoration: const InputDecoration(
                    labelText: 'Role in organization',
                    isDense: true,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPrimary,
                  title: const Text('Primary contact'),
                  onChanged: (value) =>
                      setState(() => _isPrimary = value ?? false),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _designation,
                decoration: const InputDecoration(
                  labelText: 'Designation',
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
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Phone *',
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
            ],
          ),
        ),
      ],
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
