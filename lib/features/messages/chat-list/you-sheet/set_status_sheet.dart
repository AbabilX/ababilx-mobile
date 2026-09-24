import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/user_status_repository.dart';
import '../../../profile/providers/user_status_provider.dart';

class _StatusPreset {
  const _StatusPreset(this.emoji, this.label);
  final String emoji;
  final String label;
}

const _presets = [
  _StatusPreset('📅', 'In a meeting'),
  _StatusPreset('🚗', 'Commuting'),
  _StatusPreset('🤒', 'Out sick'),
  _StatusPreset('🌴', 'Vacationing'),
  _StatusPreset('🏡', 'Working remotely'),
];

const _durations = [
  (hours: 1, label: '1 hour'),
  (hours: 4, label: '4 hours'),
  (hours: 8, label: '8 hours'),
  (hours: 24, label: '24 hours'),
];

const _defaultEmoji = '💬';

/// Set/clear the caller's own Slack-style status — presets, custom text, and
/// an auto-clear duration (backend always expires it, no "never" option).
Future<void> showSetStatusSheet(
  BuildContext context,
  WidgetRef ref,
  String currentUserId,
) {
  final current = ref.read(userStatusForProvider(currentUserId));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        _SetStatusSheet(currentUserId: currentUserId, current: current),
  );
}

class _SetStatusSheet extends ConsumerStatefulWidget {
  const _SetStatusSheet({required this.currentUserId, this.current});

  final String currentUserId;
  final UserStatus? current;

  @override
  ConsumerState<_SetStatusSheet> createState() => _SetStatusSheetState();
}

class _SetStatusSheetState extends ConsumerState<_SetStatusSheet> {
  late final TextEditingController _textCtrl;
  late String _emoji;
  late int _durationHours;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.current?.text ?? '');
    _emoji = widget.current?.emoji.isNotEmpty == true
        ? widget.current!.emoji
        : _defaultEmoji;
    _durationHours = 4;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _pickPreset(_StatusPreset preset) {
    setState(() {
      _emoji = preset.emoji;
      _textCtrl.text = preset.label;
    });
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(userStatusRepositoryProvider)
          .setStatus(emoji: _emoji, text: text, durationHours: _durationHours);
      ref
          .read(userStatusProvider.notifier)
          .setLocal(widget.currentUserId, saved);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userStatusRepositoryProvider).clearStatus();
      ref
          .read(userStatusProvider.notifier)
          .setLocal(widget.currentUserId, null);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear status. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasCurrent = widget.current?.isActive == true;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set a status',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _EmojiButton(emoji: _emoji),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        hintText: "What's your status?",
                        counterText: '',
                      ),
                      onChanged: (_) {
                        if (_emoji.isEmpty) {
                          setState(() => _emoji = _defaultEmoji);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _presets)
                    ActionChip(
                      avatar: Text(preset.emoji),
                      label: Text(preset.label),
                      onPressed: () => _pickPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Clear after',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _durations)
                    ChoiceChip(
                      label: Text(d.label),
                      selected: _durationHours == d.hours,
                      onSelected: (_) =>
                          setState(() => _durationHours = d.hours),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save status'),
              ),
              if (hasCurrent) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : _clear,
                  child: const Text('Clear status'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}
