import 'package:flutter/material.dart';

/// Which account a feed belongs to.
///
/// Only shown to someone who has a workspace: without one there is a single
/// possible answer, and a control with one option is a question not worth
/// asking. A personal feed needs no workspace at all — see migration 0128.
class WebhookScopeField extends StatelessWidget {
  const WebhookScopeField({
    super.key,
    required this.personal,
    required this.onChanged,
    this.enabled = true,
  });

  final bool personal;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(
        value: false,
        icon: Icon(Icons.groups_outlined, size: 18),
        label: Text('Workspace'),
      ),
      ButtonSegment(
        value: true,
        icon: Icon(Icons.person_outline_rounded, size: 18),
        label: Text('Personal'),
      ),
    ],
    selected: {personal},
    onSelectionChanged: enabled ? (value) => onChanged(value.first) : null,
  );
}

/// The reach line under the name field. A workspace feed offers a real choice
/// — every member, or only people added — while a personal feed starts with
/// its owner alone and says so instead of showing a switch that cannot mean
/// anything.
class WebhookReachField extends StatelessWidget {
  const WebhookReachField({
    super.key,
    required this.personal,
    required this.isPrivate,
    required this.onPrivateChanged,
    this.enabled = true,
  });

  final bool personal;
  final bool isPrivate;
  final ValueChanged<bool> onPrivateChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (personal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Only you can read it until you add someone.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Private feed'),
      subtitle: const Text('Only people you add can read it'),
      value: isPrivate,
      onChanged: enabled ? onPrivateChanged : null,
    );
  }
}
