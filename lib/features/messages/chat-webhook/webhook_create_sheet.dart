import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../chat-details/group_image_flow.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';
import 'webhook_avatar_picker.dart';
import 'webhook_scope_field.dart';
import 'webhook_url_sheet.dart';

/// Creates a one-way feed, in either scope.
///
/// A **personal** feed belongs to the account and needs no workspace at all; a
/// **workspace** feed belongs to a team and every active member reads it. The
/// choice is only offered to someone who actually has a workspace — for
/// everyone else there is one answer and no question worth asking.
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
  bool _isPrivate = false;
  bool _busy = false;

  /// Null until the team gate answers. Personal is the floor: an account
  /// without a workspace can still own a feed, so nothing here waits on a
  /// team before it will let the sheet be used.
  bool? _hasTeam;
  bool _personal = true;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveScope());
  }

  Future<void> _resolveScope() async {
    final team = await ref.read(teamGateProvider.future);
    if (!mounted) return;
    setState(() {
      _hasTeam = team?.hasTeam ?? false;
      // A workspace feed is the more useful default where one exists: its
      // members are already there to read it.
      _personal = _hasTeam != true;
    });
  }

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
          if (_hasTeam == true) ...[
            const SizedBox(height: 14),
            WebhookScopeField(
              personal: _personal,
              enabled: !_busy,
              onChanged: (value) => setState(() => _personal = value),
            ),
          ],
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
          WebhookReachField(
            personal: _personal,
            isPrivate: _isPrivate,
            enabled: !_busy,
            onPrivateChanged: (value) => setState(() => _isPrivate = value),
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
      final result = await chat.createWebhookChannel(
        name: name,
        personal: _personal,
        isPrivate: _isPrivate,
      );
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
