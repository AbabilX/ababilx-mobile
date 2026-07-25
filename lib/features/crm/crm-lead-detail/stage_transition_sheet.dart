import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import 'stage_transition_rules.dart';

class _DraftUpload {
  const _DraftUpload({
    required this.uploadId,
    required this.fileName,
  });
  final String uploadId;
  final String fileName;
}

/// Web StageTransitionDialog — work-log + optional attachments + date/time.
Future<bool> showStageTransitionSheet(
  BuildContext context, {
  required WidgetRef ref,
  required CrmLead lead,
  required List<CrmStage> stages,
  required CrmStage target,
}) async {
  final kind = stageMoveKind(lead, stages, target);
  if (kind == null) return false;

  final colors = Theme.of(context).colorScheme;
  final ok = await showModalBottomSheet<bool>(
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
        height: h * 0.88,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _StageTransitionBody(
            lead: lead,
            stages: stages,
            target: target,
            kind: kind,
          ),
        ),
      );
    },
  );
  return ok == true;
}

class _StageTransitionBody extends ConsumerStatefulWidget {
  const _StageTransitionBody({
    required this.lead,
    required this.stages,
    required this.target,
    required this.kind,
  });

  final CrmLead lead;
  final List<CrmStage> stages;
  final CrmStage target;
  final StageMoveKind kind;

  @override
  ConsumerState<_StageTransitionBody> createState() =>
      _StageTransitionBodyState();
}

class _StageTransitionBodyState extends ConsumerState<_StageTransitionBody> {
  final _description = TextEditingController();
  final _note = TextEditingController();
  late DateTime _when;
  final _uploads = <_DraftUpload>[];
  var _busy = false;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    _when = DateTime.now();
  }

  @override
  void dispose() {
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.target.isLost) return 'Mark as ${widget.target.name}';
    if (widget.kind == StageMoveKind.backward) {
      return 'Move back to ${widget.target.name}';
    }
    return 'Move to ${widget.target.name}';
  }

  bool get _lossMissing =>
      widget.target.isLost && _description.text.trim().isEmpty;

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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

  Future<void> _addFile() async {
    if (_uploads.length >= 10 || _uploading) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    setState(() => _uploading = true);
    try {
      final draft = await ref.read(crmRepositoryProvider).presignStageUpload(
            widget.lead.id,
            targetStageId: widget.target.id,
            contentType: mime,
            fileName: file.name,
            sizeBytes: bytes.length,
          );
      final dio = Dio();
      final put = await dio.put(
        draft.uploadUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': mime}),
      );
      if (put.statusCode == null ||
          put.statusCode! < 200 ||
          put.statusCode! >= 300) {
        await ref.read(crmRepositoryProvider).discardStageUpload(draft.uploadId);
        throw Exception('Upload failed');
      }
      if (!mounted) return;
      setState(() {
        _uploads.add(
          _DraftUpload(uploadId: draft.uploadId, fileName: file.name),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _discardAll() async {
    for (final u in _uploads) {
      try {
        await ref.read(crmRepositoryProvider).discardStageUpload(u.uploadId);
      } catch (_) {}
    }
    _uploads.clear();
  }

  Future<void> _cancel() async {
    if (_busy || _uploading) return;
    await _discardAll();
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  Future<void> _submit() async {
    if (_lossMissing || _busy || _uploading) return;
    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).commitLeadStageTransition(
            widget.lead.id,
            stageId: widget.target.id,
            pipelineId: widget.lead.pipelineId ?? widget.target.pipelineId,
            occurredAt: _when.toUtc().toIso8601String(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            uploadIds: _uploads.map((u) => u.uploadId).toList(),
          );
      invalidateLeadDetail(ref, widget.lead.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to ${widget.target.name}')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    CrmStage? current;
    for (final s in widget.stages) {
      if (s.id == widget.lead.stageId) {
        current = s;
        break;
      }
    }
    final canSubmit = !_lossMissing && !_busy && !_uploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: canSubmit ? _submit : null,
                child: Text(
                  'Confirm',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: canSubmit ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.5)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                '${current?.name ?? 'Current'} → ${widget.target.name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (widget.target.isLost) ...[
                const SizedBox(height: 10),
                Material(
                  color: colors.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Closing as lost skips unfinished stages. Description is required.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: widget.target.isLost
                      ? 'What happened? (required)'
                      : 'What happened? (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Internal note (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('When'),
                subtitle: Text(
                  '${_when.year}-${_when.month.toString().padLeft(2, '0')}-${_when.day.toString().padLeft(2, '0')} '
                  '${_when.hour.toString().padLeft(2, '0')}:${_when.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: _busy ? null : _pickWhen,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Attachments',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _uploads.length >= 10 || _busy || _uploading
                        ? null
                        : _addFile,
                    icon: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              for (final u in _uploads)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(u.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _busy
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(crmRepositoryProvider)
                                  .discardStageUpload(u.uploadId);
                            } catch (_) {}
                            setState(() => _uploads.remove(u));
                          },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
