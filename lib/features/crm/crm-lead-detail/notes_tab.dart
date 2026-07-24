import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';

class NotesTab extends ConsumerStatefulWidget {
  const NotesTab({
    super.key,
    required this.leadId,
    required this.notes,
    required this.canCreate,
    required this.canDelete,
  });

  final String leadId;
  final List<CrmNote> notes;
  final bool canCreate;
  final bool canDelete;

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  final _ctrl = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).createNote(widget.leadId, body);
      _ctrl.clear();
      invalidateLeadDetail(ref, widget.leadId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
            controller: _ctrl,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Add a note…',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy || _ctrl.text.trim().isEmpty ? null : _add,
              child: Text(_busy ? 'Saving…' : 'Add note'),
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
