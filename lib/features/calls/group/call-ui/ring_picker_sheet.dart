import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../messages/data/models/chat_models.dart';
import '../call_icons.dart';

/// What the sheet answers. [ids] null = ring everyone; a set = exactly those
/// people (empty = nobody). The sheet itself returns null for "backed out",
/// which is why this is a box and not a bare `Set?`.
class RingPick {
  const RingPick(this.ids);
  final Set<String>? ids;
}

/// Who a new group call rings (server 0172). Everyone not ticked still sees
/// the call in the chat and can join; only the ringing is skipped.
Future<RingPick?> showRingPickerSheet(
  BuildContext context, {
  required List<ChatMember> members,
  required Set<String>? selected,
}) {
  return showModalBottomSheet<RingPick>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RingPickerSheet(members: members, selected: selected),
  );
}

class _RingPickerSheet extends StatefulWidget {
  const _RingPickerSheet({required this.members, required this.selected});

  final List<ChatMember> members;
  final Set<String>? selected;

  @override
  State<_RingPickerSheet> createState() => _RingPickerSheetState();
}

class _RingPickerSheetState extends State<_RingPickerSheet> {
  late final Set<String> _ids =
      widget.selected?.toSet() ?? widget.members.map((m) => m.userId).toSet();
  String _query = '';

  bool get _everyone => _ids.length == widget.members.length;

  void _toggleEveryone() => setState(() {
    if (_everyone) {
      _ids.clear();
    } else {
      _ids.addAll(widget.members.map((m) => m.userId));
    }
  });

  void _done() =>
      Navigator.pop(context, RingPick(_everyone ? null : _ids.toSet()));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.members
        : widget.members
              .where((m) => m.name.toLowerCase().contains(q))
              .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Who to ring', style: text.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Everyone else can still see the call and join it.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (widget.members.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    isDense: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(10),
                      child: CallIcon(
                        HugeIcons.strokeRoundedSearch01,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              value: _everyone ? true : (_ids.isEmpty ? false : null),
              tristate: true,
              onChanged: (_) => _toggleEveryone(),
              secondary: CircleAvatar(
                radius: 20,
                backgroundColor: scheme.secondaryContainer,
                child: CallIcon(
                  CallIcons.participants,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              title: const Text('Everyone'),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in shown)
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      value: _ids.contains(m.userId),
                      onChanged: (on) => setState(
                        () => on == true
                            ? _ids.add(m.userId)
                            : _ids.remove(m.userId),
                      ),
                      secondary: ClipOval(
                        child: AppAvatar(
                          size: 40,
                          url: m.avatarUrl,
                          name: m.name,
                        ),
                      ),
                      title: Text(m.name),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton(
                onPressed: _done,
                child: Text(_doneLabel(_everyone, _ids.length)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _doneLabel(bool everyone, int count) {
  if (everyone) return 'Ring everyone';
  if (count == 0) return 'Ring nobody';
  return count == 1 ? 'Ring 1 person' : 'Ring $count people';
}

/// The lobby row's summary of the current pick.
String ringSummary(Set<String>? ids, int memberCount) {
  if (ids == null || ids.length >= memberCount) return 'Everyone';
  if (ids.isEmpty) return 'Nobody';
  return ids.length == 1 ? '1 person' : '${ids.length} people';
}
