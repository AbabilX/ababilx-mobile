import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../engine/protocol/share_peer.dart';
import '../providers/local_share_name.dart';
import '../share_text.dart';

/// Asks what this device should be called on a local network. Returns true
/// once a name is saved.
Future<bool> showDeviceNameSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _DeviceNameSheet(),
  );
  return saved ?? false;
}

class _DeviceNameSheet extends ConsumerStatefulWidget {
  const _DeviceNameSheet();

  @override
  ConsumerState<_DeviceNameSheet> createState() => _DeviceNameSheetState();
}

class _DeviceNameSheetState extends ConsumerState<_DeviceNameSheet> {
  late final TextEditingController _controller;
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(localShareNameProvider).valueOrNull;
    final account = ref.read(profileProvider).valueOrNull?.name.trim() ?? '';
    final first = account.split(' ').first;
    // A suggestion, not a default: the user sees it and may type over it.
    final suggestion = first.isEmpty ? '' : "$first's phone";
    _controller = TextEditingController(text: current ?? suggestion);
    _valid = cleanShareName(_controller.text) != null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref
        .read(localShareNameProvider.notifier)
        .save(_controller.text);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lsText(ref, 'ls_name_title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            lsText(ref, 'ls_name_body'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: shareNameMaxLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              final valid = cleanShareName(value) != null;
              if (valid != _valid) setState(() => _valid = valid);
            },
            onSubmitted: (_) => _valid ? _save() : null,
            decoration: InputDecoration(
              hintText: lsText(ref, 'ls_name_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _save : null,
              child: Text(lsText(ref, 'ls_name_save')),
            ),
          ),
        ],
      ),
    );
  }
}
