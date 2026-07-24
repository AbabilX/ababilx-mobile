import 'package:flutter/material.dart';

/// Complete follow-up → outcome + optional next date (web CompleteFollowupDialog).
class CompleteFollowupResult {
  const CompleteFollowupResult({required this.outcome, this.nextAt});
  final String outcome;
  final DateTime? nextAt;
}

Future<CompleteFollowupResult?> showCompleteFollowupSheet(
  BuildContext context, {
  required String title,
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<CompleteFollowupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _CompleteBody(title: title),
    ),
  );
}

class _CompleteBody extends StatefulWidget {
  const _CompleteBody({required this.title});
  final String title;

  @override
  State<_CompleteBody> createState() => _CompleteBodyState();
}

class _CompleteBodyState extends State<_CompleteBody> {
  final _outcome = TextEditingController();
  DateTime? _nextAt;

  @override
  void dispose() {
    _outcome.dispose();
    super.dispose();
  }

  Future<void> _pickNext() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (t == null || !mounted) return;
    setState(() {
      _nextAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Complete follow-up',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _outcome,
            decoration: const InputDecoration(
              labelText: 'Outcome (optional)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Next follow-up (optional)'),
            subtitle: Text(
              _nextAt == null
                  ? 'None'
                  : _nextAt!.toLocal().toString().substring(0, 16),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_nextAt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _nextAt = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: _pickNext,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              CompleteFollowupResult(
                outcome: _outcome.text.trim(),
                nextAt: _nextAt,
              ),
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}
