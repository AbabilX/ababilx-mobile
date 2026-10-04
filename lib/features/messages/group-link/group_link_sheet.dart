import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../settings/username/username_rules.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_link_actions.dart';
import 'group_link_api.dart';
import 'group_link_payload.dart';

/// The admin's sheet for a group's public link: choose the last part, save,
/// then copy, share, pause or remove it. The server owns uniqueness; a taken link comes back
/// as a line under the field.
Future<void> showGroupLinkSheet(
  BuildContext context,
  ChatConversation conversation,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(sheet).bottom + 24,
    ),
    child: SafeArea(child: _LinkForm(conversation: conversation)),
  ),
);

class _LinkForm extends ConsumerStatefulWidget {
  const _LinkForm({required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends ConsumerState<_LinkForm> {
  late final _field = TextEditingController(
    text: widget.conversation.publicLink,
  );
  late String _saved = widget.conversation.publicLink;
  late bool _paused = widget.conversation.publicLinkPaused;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// One round trip for every action: save, pause, resume, remove.
  Future<void> _run(
    Future<GroupLinkState> Function(ApiClient client, String id) action,
    String done,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await action(
        ref.read(apiClientProvider),
        widget.conversation.id,
      );
      // The link rides on the sidebar row; re-read it rather than patch.
      await ref.read(chatProvider.notifier).fetchSidebarSilent();
      if (!mounted) return;
      setState(() {
        _saved = state.slug;
        _paused = state.paused;
        _field.text = state.slug;
      });
      showAppToast(context, done);
    } on GroupLinkRefused catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typed = normalizeUsername(_field.text);
    final canSave = !_busy && typed != _saved && isValidUsername(typed);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Public link', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Anyone with this link can see the group’s name and join it. '
          'A group has one link, and it can be changed once every 3 days.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _field,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: usernameMaxLength,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            prefixText: groupLinkPrefix,
            hintText: 'your-group',
            errorText: _error ?? usernameError(_field.text),
            errorMaxLines: 3,
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: canSave
              ? () => _run((c, id) => putGroupLink(c, id, typed), 'Link saved')
              : null,
          child: const Text('Save'),
        ),
        if (_saved.isNotEmpty)
          GroupLinkActions(
            link: buildGroupLink(_saved),
            paused: _paused,
            busy: _busy,
            onPause: (pause) => _run(
              (c, id) => pauseGroupLink(c, id, paused: pause),
              pause ? 'Link paused' : 'Link is working again',
            ),
            onRemove: () => _run(deleteGroupLink, 'Link removed'),
          ),
      ],
    );
  }
}
