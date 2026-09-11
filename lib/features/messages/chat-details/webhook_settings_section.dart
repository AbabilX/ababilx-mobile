import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../chat-webhook/webhook_url_sheet.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'details_tile.dart';
import 'group_image_flow.dart';
import 'group_permissions.dart';

/// The feed block on the details screen: replace the posting URL, change the
/// bot picture.
///
/// There is no "show me the current URL" — the server keeps a hash of the
/// token and nothing else, so the only way to see a URL is to mint a new one,
/// which is exactly what [_regenerate] warns about before it does it.
class WebhookSettingsSection extends ConsumerStatefulWidget {
  const WebhookSettingsSection({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<WebhookSettingsSection> createState() =>
      _WebhookSettingsSectionState();
}

class _WebhookSettingsSectionState
    extends ConsumerState<WebhookSettingsSection> {
  bool _busy = false;

  /// What this screen just saved. Messages already on screen keep the avatar
  /// the server joined onto them when they were fetched, so without this a
  /// removed photo would go on reading as "Set" until the feed posted again.
  String? _justSaved;
  bool _saved = false;

  /// The feed's picture. The server mirrors the webhook's avatar onto the
  /// conversation row, so that is the answer wherever it is there.
  ///
  /// The fallback reads it off a message the feed has already posted — the
  /// server joins the hook's avatar into that column — which is all a build
  /// talking to a server from before the mirror can see. It is skipped once
  /// this screen has saved, or a removed photo would go on reading as "Set"
  /// from the stale messages already on screen.
  String? get _currentAvatar {
    if (_saved) return _justSaved;
    final conversation =
        ref.watch(chatProvider).conversationById(widget.conversation.id) ??
        widget.conversation;
    final mirrored = conversation.avatarUrl?.trim() ?? '';
    if (mirrored.isNotEmpty) return mirrored;
    final feed = ref.watch(chatProvider).feeds[feedKey(widget.conversation.id)];
    for (final message in (feed?.messages ?? const []).reversed) {
      final url = message.userAvatarUrl?.trim() ?? '';
      if (message.isWebhook && url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!GroupPermissions(widget.conversation).canManage) {
      return const SizedBox.shrink();
    }
    final avatar = _currentAvatar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.conversation.isPersonal)
          DetailsTile(
            icon: const Icon(Icons.person_outline_rounded),
            title: 'Personal feed',
            value: 'Belongs to your account, not to a workspace',
          ),
        DetailsTile(
          icon: const Icon(Icons.link_rounded),
          title: 'Webhook URL',
          value: 'Generate a new one — the old URL stops working',
          onTap: _busy ? null : _regenerate,
        ),
        DetailsTile(
          icon: const Icon(Icons.photo_camera_outlined),
          title: 'Feed photo',
          value: avatar == null ? 'Not set' : 'Set',
          onTap: _busy ? null : _pickPhoto,
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : avatar == null
              ? null
              : IconButton(
                  tooltip: 'Remove photo',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _saveAvatar(null),
                ),
        ),
      ],
    );
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate a new URL?'),
        content: const Text(
          'Whatever is posting to this feed stops working until you give it '
          'the new URL. The current one cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(chatProvider.notifier)
          .regenerateWebhook(widget.conversation);
      if (mounted) {
        await showWebhookUrlSheet(context, url: result.url, isNew: false);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Could not generate a URL', isError: true);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickGroupImage(context, GroupImageKind.photo);
    if (bytes != null) await _saveAvatar(bytes);
  }

  Future<void> _saveAvatar(Uint8List? bytes) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(chatProvider.notifier)
          .setWebhookAvatar(widget.conversation, bytes);
      if (mounted) {
        _saved = true;
        _justSaved = saved.isEmpty ? null : saved;
        showAppToast(
          context,
          bytes == null ? 'Feed photo removed' : 'Feed photo updated',
        );
      }
    } catch (_) {
      if (mounted) showAppToast(context, 'Could not save photo', isError: true);
    }
    if (mounted) setState(() => _busy = false);
  }
}
