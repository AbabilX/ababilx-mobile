import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/pdf_preview.dart';
import '../../../shared/widgets/voice_url_player.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_media_actions.dart';
import '../shared/crm_ui.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';

class DocumentsTab extends ConsumerStatefulWidget {
  const DocumentsTab({
    super.key,
    required this.leadId,
    required this.documents,
    required this.canCreate,
    required this.canDelete,
    this.shrinkWrap = false,
  });

  final String leadId;
  final List<CrmDocument> documents;
  final bool canCreate;
  final bool canDelete;
  final bool shrinkWrap;

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

  Future<void> _upload(PickedMediaFile file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(crmRepositoryProvider)
          .uploadDocument(
            widget.leadId,
            bytes: file.bytes,
            fileName: file.fileName,
            mimeType: file.contentType,
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          );
      _label.clear();
      invalidateLeadDetail(ref, widget.leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadVoice(RecordedVoiceMessage recording) async {
    await _upload(await pickedVoiceRecording(recording));
  }

  Future<void> _delete(CrmDocument d) async {
    try {
      await ref.read(crmRepositoryProvider).deleteDocument(d.id);
      invalidateLeadDetail(ref, widget.leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _open(CrmDocument d) async {
    if (d.isPdf) {
      await showPdfPreview(
        context,
        fileUrl: d.fileUrl,
        fileName: d.fileName,
      );
      return;
    }
    final uri = Uri.tryParse(d.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: widget.shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.canCreate) ...[
          Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(
                    hintText: 'Optional label — e.g. NID, Contract',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 12, 6),
                  child: Row(
                    children: [
                      CrmMediaActions(
                        busy: _busy,
                        onMedia: _upload,
                        onVoice: _uploadVoice,
                      ),
                      const Spacer(),
                      Text(
                        _busy ? 'Uploading…' : 'Mic · Camera · Files',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.documents.isEmpty)
          const CrmEmpty(message: 'No documents yet.')
        else
          for (final d in widget.documents) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      d.isAudio
                          ? Icons.graphic_eq_rounded
                          : Icons.insert_drive_file_outlined,
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
                    onTap: d.isAudio ? null : () => _open(d),
                    trailing: widget.canDelete
                        ? IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colors.error,
                            ),
                            onPressed: () => _delete(d),
                          )
                        : null,
                  ),
                  if (d.isAudio)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: VoiceUrlPlayer(
                        url: d.fileUrl,
                        fileName: d.fileName,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}
