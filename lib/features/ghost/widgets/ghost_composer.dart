import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat-timeline/composer_input_bar_buttons.dart';
import '../providers/ghost_provider.dart';
import 'ghost_attach.dart';
import 'ghost_labels.dart';

/// Text, attach, send — drawn like the DM composer (`ComposerInputBar`): one
/// rounded pill and one accent circle beside it. Disabled until the phones
/// are connected.
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
    final source = await chooseGhostSource(context, ref);
    if (source != null && mounted) {
      await pickAndSendGhost(context, ref, source);
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
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: IgnorePointer(
                  ignoring: !on,
                  child: Opacity(
                    opacity: on ? 1 : 0.5,
                    child: _pill(colors, on),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: on ? 1 : 0.5,
                child: AccentCircle(
                  sending: false,
                  label: ghostText(ref, 'ghost_send'),
                  icon: HugeIcons.strokeRoundedSend,
                  rotated: false,
                  onTap: on ? _send : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(ColorScheme colors, bool on) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 16),
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
              style: const TextStyle(fontSize: 16, height: 1.3),
              decoration: InputDecoration(
                hintText: ghostText(ref, 'ghost_message_hint'),
                hintMaxLines: 1,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: colors.onSurfaceVariant,
                ),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
              ),
            ),
          ),
          PillIcon(
            icon: HugeIcons.strokeRoundedAttachment,
            tooltip: ghostText(ref, 'ghost_attach'),
            onTap: () => unawaited(_attach()),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
