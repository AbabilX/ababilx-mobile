import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_repository.dart';
import '../data/models/crm_models.dart';
import '../providers/crm_lead_detail_provider.dart';
import '../shared/crm_dates.dart';
import '../shared/crm_ui.dart';

const _none = '__none__';

class ActivitiesTab extends ConsumerStatefulWidget {
  const ActivitiesTab({
    super.key,
    required this.leadId,
    required this.activities,
    required this.activityTypes,
    required this.canCreate,
  });

  final String leadId;
  final List<CrmActivity> activities;
  final List<CrmActivityType> activityTypes;
  final bool canCreate;

  @override
  ConsumerState<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends ConsumerState<ActivitiesTab> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  var _typeId = _none;
  var _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy) return;
    if (_subject.text.trim().isEmpty && _body.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(crmRepositoryProvider).createActivity(
            widget.leadId,
            CrmActivityInput(
              activityTypeId: _typeId == _none ? null : _typeId,
              subject: _subject.text.trim(),
              body: _body.text.trim(),
            ),
          );
      _subject.clear();
      _body.clear();
      setState(() => _typeId = _none);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.canCreate) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_typeId),
                        initialValue: _typeId,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: _none,
                            child: Text('None'),
                          ),
                          for (final t in widget.activityTypes)
                            DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _typeId = v ?? _none),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _subject,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _body,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Details…',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy ? null : _add,
                    child: Text(_busy ? 'Saving…' : 'Log activity'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.activities.isEmpty)
          const CrmEmpty(message: 'No activities logged.')
        else
          for (final a in widget.activities)
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            a.activityTypeName ?? 'Activity',
                            if (a.subject.isNotEmpty) a.subject,
                          ].join(' · '),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        formatCrmDateTime(a.occurredAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (a.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      a.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}
