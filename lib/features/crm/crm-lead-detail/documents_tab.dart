import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';

class DocumentsTab extends ConsumerStatefulWidget {
  const DocumentsTab({
    super.key,
    required this.leadId,
    required this.documents,
    required this.canCreate,
    required this.canDelete,
  });

  final String leadId;
  final List<CrmDocument> documents;
  final bool canCreate;
  final bool canDelete;

  @override
  ConsumerState<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<DocumentsTab> {
  final _label = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    if (_busy) return;
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).uploadDocument(
            widget.leadId,
            bytes: Uint8List.fromList(bytes),
            fileName: f.name,
            mimeType: f.extension != null
                ? _mimeForExt(f.extension!)
                : 'application/octet-stream',
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          );
      _label.clear();
      invalidateLeadDetail(ref, widget.leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CrmDocument d) async {
    try {
      await ref.read(crmRepositoryProvider).deleteDocument(d.id);
      invalidateLeadDetail(ref, widget.leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _open(CrmDocument d) async {
    final uri = Uri.tryParse(d.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.canCreate) ...[
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. NID, Contract',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : _upload,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(_busy ? 'Uploading…' : 'Upload document'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.documents.isEmpty)
          const CrmEmpty(message: 'No documents yet.')
        else
          for (final d in widget.documents)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                leading: Icon(
                  Icons.insert_drive_file_outlined,
                  color: colors.primary,
                ),
                title: Text(
                  d.label.isNotEmpty ? d.label : d.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  [
                    if (d.label.isNotEmpty) d.fileName,
                    if ((d.uploaderName ?? '').isNotEmpty) d.uploaderName!,
                    formatCrmDate(d.createdAt),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                onTap: () => _open(d),
                trailing: widget.canDelete
                    ? IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.error),
                        onPressed: () => _delete(d),
                      )
                    : null,
              ),
            ),
      ],
    );
  }
}
