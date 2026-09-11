import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../chat-details/group_image_flow.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'webhook_avatar_picker.dart';
import 'webhook_url_sheet.dart';

/// Creates a one-way feed. It belongs to the account that makes it, starts
/// with that person alone, and needs no workspace — since the server's
/// migration 0145 there is no other kind to choose between.
///
/// Returns the new conversation, or null if the user backed out. The secret
/// URL is shown by this sheet before it pops — it exists for one response and
/// there is no endpoint that can read it back.
Future<ChatConversation?> showWebhookCreateSheet(
  BuildContext context,
  WidgetRef ref,
) => showModalBottomSheet<ChatConversation>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: const _WebhookCreateSheet(),
  ),
);

class _WebhookCreateSheet extends ConsumerStatefulWidget {
  const _WebhookCreateSheet();

  @override
  ConsumerState<_WebhookCreateSheet> createState() =>
      _WebhookCreateSheetState();
}

class _WebhookCreateSheetState extends ConsumerState<_WebhookCreateSheet> {
  final _name = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New webhook feed', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A group nobody can post into. Messages arrive over its URL.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          WebhookAvatarPicker(
            photo: _photo,
            onPick: _pickPhoto,
            onClear: () => setState(() => _photo = null),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Feed name',
              hintText: 'Deploys',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Only you can read it until you add someone.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _name.text.trim().isEmpty ? null : _create,
            child: Text(_busy ? 'Creating…' : 'Create feed'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickGroupImage(context, GroupImageKind.photo);
    if (bytes != null && mounted) setState(() => _photo = bytes);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final chat = ref.read(chatProvider.notifier);
    try {
      final result = await chat.createWebhookChannel(name: name);
      final conversation = result.conversation;
      // The picture is a second call and is allowed to fail on its own: the
      // feed and its URL already exist, and losing the URL to a failed avatar
      // upload would mean losing it for good.
      if (_photo != null) {
        try {
          await chat.setWebhookAvatar(conversation, _photo);
        } catch (_) {
          if (mounted) {
            showAppToast(context, 'Feed created, photo failed', isError: true);
          }
        }
      }
      if (!mounted) return;
      await showWebhookUrlSheet(context, url: result.created.url, isNew: true);
      if (mounted) Navigator.of(context).pop(conversation);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, 'Could not create feed', isError: true);
      }
    }
  }
}
