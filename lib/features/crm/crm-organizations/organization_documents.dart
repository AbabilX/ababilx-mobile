import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/friendly_error.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/locked_file_placeholder.dart';
import '../../../shared/widgets/pdf_preview.dart';
import '../../../shared/widgets/voice_url_player.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_organizations_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_media_actions.dart';
import '../shared/crm_ui.dart';

class OrganizationDocuments extends ConsumerStatefulWidget {
  const OrganizationDocuments({
    super.key,
    required this.organizationId,
    required this.canCreate,
    required this.canDelete,
  });

  final String organizationId;
  final bool canCreate;
  final bool canDelete;

  @override
  ConsumerState<OrganizationDocuments> createState() =>
      _OrganizationDocumentsState();
}

class _OrganizationDocumentsState extends ConsumerState<OrganizationDocuments> {
  final _title = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _upload(PickedMediaFile file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(crmRepositoryProvider)
          .uploadOrganizationDocument(
            widget.organizationId,
            bytes: file.bytes,
            fileName: file.fileName,
            mimeType: file.contentType,
            title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          );
      _title.clear();
      ref.invalidate(crmOrganizationDocumentsProvider(widget.organizationId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document uploaded')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadVoice(RecordedVoiceMessage recording) async {
    await _upload(await pickedVoiceRecording(recording));
  }

  Future<void> _delete(CrmOrganizationDocument document) async {
    try {
      await ref
          .read(crmRepositoryProvider)
          .deleteOrganizationDocument(document.id);
      ref.invalidate(crmOrganizationDocumentsProvider(widget.organizationId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    }
  }

  Future<void> _open(CrmOrganizationDocument document) async {
    if (document.locked || document.url.isEmpty) return;
    if (document.isPdf) {
      await showPdfPreview(
        context,
        source: PdfDocumentSource.url(document.url),
        fileName: document.fileName.isNotEmpty
            ? document.fileName
            : document.title,
      );
      return;
    }
    final uri = Uri.tryParse(document.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(
      crmOrganizationDocumentsProvider(widget.organizationId),
    );
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (widget.canCreate) ...[
          Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    hintText: 'Optional document title',
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
        documents.when(
          loading: () => const CrmLoading(),
          error: (error, _) =>
              CrmErrorBox(message: friendlyErrorMessage(error)),
          data: (items) {
            if (items.isEmpty) {
              return const CrmEmpty(message: 'No organization documents yet.');
            }
            return Column(
              children: [
                for (final document in items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(
                            document.locked
                                ? Icons.lock_outline_rounded
                                : document.isAudio
                                ? Icons.graphic_eq_rounded
                                : Icons.insert_drive_file_outlined,
                            color: document.locked
                                ? colors.onSurfaceVariant
                                : colors.primary,
                          ),
                          title: Text(
                            document.title.isNotEmpty
                                ? document.title
                                : document.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: document.locked
                                ? TextStyle(color: colors.onSurfaceVariant)
                                : null,
                          ),
                          subtitle: Text(
                            [
                              document.uploaderName ?? 'Workspace member',
                              formatCrmDate(document.createdAt),
                              if (document.locked) 'Locked',
                            ].join(' · '),
                          ),
                          onTap: (document.locked || document.isAudio)
                              ? null
                              : () => _open(document),
                          trailing: widget.canDelete
                              ? IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(document),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colors.error,
                                  ),
                                )
                              : null,
                        ),
                        if (document.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Text(document.description),
                          ),
                        if (document.isAudio && !document.locked)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: VoiceUrlPlayer(
                              source: AudioSourceRef.url(document.url),
                              fileName: document.fileName,
                              compact: true,
                            ),
                          )
                        else if (document.isAudio && document.locked)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: LockedFilePlaceholder(
                              fileName: '',
                              compact: false,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
