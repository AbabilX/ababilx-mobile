import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import 'ghost_labels.dart';
import 'ghost_pick.dart';

/// Text, attach, send. Disabled until the phones are connected.
///
/// The field turns off the keyboard's suggestions and personalised learning:
/// Gboard and friends otherwise remember what was typed here, which is a copy
/// of the chat living on after the burn.
class GhostComposer extends ConsumerStatefulWidget {
  const GhostComposer({super.key, required this.enabled});

  final bool enabled;

  @override
  ConsumerState<GhostComposer> createState() => _GhostComposerState();
}

class _GhostComposerState extends ConsumerState<GhostComposer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    final sent = await ref.read(ghostProvider.notifier).sendText(text);
    if (sent && mounted) _text.clear();
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<GhostPickSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (src, icon, key) in [
              (
                GhostPickSource.gallery,
                HugeIcons.strokeRoundedImage01,
                'ghost_photo',
              ),
              (
                GhostPickSource.camera,
                HugeIcons.strokeRoundedCamera01,
                'ghost_camera',
              ),
              (
                GhostPickSource.file,
                HugeIcons.strokeRoundedFile01,
                'ghost_file',
              ),
            ])
              ListTile(
                leading: ChatIcon(icon),
                title: Text(ghostText(ref, key)),
                onTap: () => Navigator.of(sheet).pop(src),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await pickForGhost(source);
      if (picked == null) return;
      await ref
          .read(ghostProvider.notifier)
          .sendFile(picked.name, picked.mime, picked.bytes);
    } on GhostFileTooLarge {
      if (mounted) {
        showAppToast(
          context,
          ghostText(ref, 'ghost_err_file_too_large'),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          ghostText(ref, 'ghost_err_generic'),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final on = widget.enabled;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: on ? _attach : null,
                icon: const ChatIcon(HugeIcons.strokeRoundedAttachment01),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  enabled: on,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: ref.read(ghostProvider.notifier).onDraftChanged,
                  decoration: InputDecoration(
                    hintText: ghostText(ref, 'ghost_message_hint'),
                    counterText: '',
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: on ? _send : null,
                icon: const ChatIcon(
                  HugeIcons.strokeRoundedSent,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
