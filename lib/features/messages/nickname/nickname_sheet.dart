import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text/display_name.dart';
import 'contact_nickname_provider.dart';

/// The reference app's "Nickname" editor: rename someone on this device.
///
/// The field opens on their current nickname, or empty when there is none, and
/// saving an empty field clears it back to the name they chose for themselves.
Future<void> showNicknameSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String? profileName,
}) {
  final current = ref.read(contactNicknamesProvider).forUser(userId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _NicknameSheet(
      userId: userId,
      profileName: profileName,
      initial: current ?? '',
    ),
  );
}

class _NicknameSheet extends ConsumerStatefulWidget {
  const _NicknameSheet({
    required this.userId,
    required this.profileName,
    required this.initial,
  });

  final String userId;
  final String? profileName;
  final String initial;

  @override
  ConsumerState<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends ConsumerState<_NicknameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(contactNicknamesProvider.notifier)
        .setNickname(widget.userId, _controller.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theirName = safeDisplayName(widget.profileName, fallback: '');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nickname',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            theirName.isEmpty
                // Exactly the case this exists for: their own name renders as
                // nothing, so there is no "instead of" to name.
                ? 'This name is only stored on your phone. They are never told.'
                : 'Shown instead of "$theirName", on this phone only. '
                      'They are never told.',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            maxLength: displayNameMaxRunes,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Name for this person',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.initial.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _controller.clear();
                    _save();
                  },
                  child: const Text('Remove'),
                ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
