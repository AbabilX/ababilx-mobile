import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/action_composer.dart';
import '../../messages/chat-timeline/voice_message_recorder.dart';
import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_media_actions.dart';
import '../shared/crm_ui.dart';

class NotesTab extends ConsumerStatefulWidget {
  const NotesTab({
    super.key,
    required this.leadId,
    required this.notes,
    required this.canCreate,
    required this.canDelete,
    this.shrinkWrap = false,
  });

  final String leadId;
  final List<CrmNote> notes;
  final bool canCreate;
  final bool canDelete;
  final bool shrinkWrap;

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _pending = <PickedMediaFile>[];
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onDraftChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final body = _ctrl.text.trim();
    if ((body.isEmpty && _pending.isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(crmRepositoryProvider);
      while (_pending.isNotEmpty) {
        final file = _pending.first;
        await repo.uploadDocument(
          widget.leadId,
          bytes: file.bytes,
          fileName: file.fileName,
          mimeType: file.contentType,
        );
        _pending.removeAt(0);
      }
      if (body.isNotEmpty) {
        await repo.createNote(widget.leadId, body);
      }
      _ctrl.clear();
      invalidateLeadDetail(ref, widget.leadId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _queueMedia(PickedMediaFile file) async {
    if (!mounted) return;
    setState(() => _pending.add(file));
  }

  Future<void> _sendVoice(RecordedVoiceMessage recording) async {
    final file = await pickedVoiceRecording(recording);
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(crmRepositoryProvider)
          .uploadDocument(
            widget.leadId,
            bytes: file.bytes,
            fileName: file.fileName,
            mimeType: file.contentType,
            label: 'Voice note',
          );
      invalidateLeadDetail(ref, widget.leadId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CrmNote n) async {
    try {
      await ref.read(crmRepositoryProvider).deleteNote(n.id);
      invalidateLeadDetail(ref, widget.leadId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
          ActionComposer(
            controller: _ctrl,
            focusNode: _focus,
            hint: 'Add a note…',
            busy: _busy,
            canSend: _ctrl.text.trim().isNotEmpty || _pending.isNotEmpty,
            embedded: true,
            minLines: 2,
            maxLines: 5,
            pending: _pending.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < _pending.length; i++)
                            InputChip(
                              avatar: Icon(
                                _pending[i].contentType.startsWith('image/')
                                    ? Icons.image_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 17,
                              ),
                              label: Text(
                                _pending[i].fileName,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: _busy
                                  ? null
                                  : () => setState(() => _pending.removeAt(i)),
                            ),
                        ],
                      ),
                    ),
                  ),
            actions: [
              CrmMediaActions(
                busy: _busy,
                onMedia: _queueMedia,
                onVoice: _sendVoice,
              ),
            ],
            onSend: _add,
          ),
          const SizedBox(height: 6),
          Text(
            'Hold mic to send a voice note · camera and files attach to this lead',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.notes.isEmpty)
          const CrmEmpty(message: 'No notes yet.')
        else
          for (final n in widget.notes)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            n.authorName ?? '—',
                            formatCrmDate(n.createdAt),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (widget.canDelete)
                        TextButton(
                          onPressed: () => _delete(n),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                          child: const Text('Delete'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
