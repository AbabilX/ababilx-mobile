import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'composer_input_bar_buttons.dart';
import 'composer_keyboard_content.dart';

/// Signal's composer: one pill holding emoji, the text field, camera and mic,
/// with a single accent circle beside it.
///
/// That circle is the only send affordance. It is "+" while there is nothing
/// to send and becomes the arrow the moment there is, which is also why camera
/// and mic hide at that point — Signal keeps exactly one row and swaps what
/// sits in it rather than growing a second toolbar above the keyboard.
class ComposerInputBar extends StatelessWidget {
  const ComposerInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sending,
    required this.canSend,
    required this.attachmentOpen,
    required this.onEmoji,
    required this.onCamera,
    required this.onVoice,
    required this.onPlus,
    required this.onSend,
    this.preparingVoice = false,
    this.onContentInserted,
    this.emojiTooltip = 'Emoji',
    this.cameraTooltip = 'Camera',
    this.voiceTooltip = 'Voice',
    this.attachTooltip = 'Attach',
    this.sendLabel = 'Send',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool sending;
  final bool canSend;

  /// The attachment keyboard is showing, so "+" reads as a close affordance.
  final bool attachmentOpen;
  final bool preparingVoice;
  final VoidCallback onEmoji;
  final VoidCallback onCamera;
  final VoidCallback onVoice;
  final VoidCallback onPlus;
  final VoidCallback onSend;

  /// A sticker or GIF from the keyboard. Null leaves the field text-only.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;
  final String emojiTooltip;
  final String cameraTooltip;
  final String voiceTooltip;
  final String attachTooltip;
  final String sendLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PillIcon(
                    icon: HugeIcons.strokeRoundedSmile,
                    tooltip: emojiTooltip,
                    onTap: onEmoji,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 16, height: 1.3),
                      textCapitalization: TextCapitalization.sentences,
                      contentInsertionConfiguration: onContentInserted == null
                          ? null
                          : ContentInsertionConfiguration(
                              onContentInserted: onContentInserted!,
                              allowedMimeTypes: keyboardContentMimeTypes,
                            ),
                      decoration: InputDecoration(
                        hintText: hint,
                        // A long peer name ("Message Junayed Ahamed") wrapped
                        // and opened the composer two lines tall before a
                        // single character was typed.
                        hintMaxLines: 1,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                      ),
                    ),
                  ),
                  // Camera and mic are send-adjacent shortcuts, so they hide
                  // once there is a draft (the circle beside the pill is
                  // "send" then, and a camera next to it would be a second,
                  // competing send path). Attach stays reachable either way —
                  // it opens the same keyboard the "+" circle opens when
                  // empty, so a draft in progress never blocks adding a file.
                  if (!canSend) ...[
                    PillIcon(
                      icon: HugeIcons.strokeRoundedCamera01,
                      tooltip: cameraTooltip,
                      onTap: onCamera,
                    ),
                    preparingVoice
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : PillIcon(
                            icon: HugeIcons.strokeRoundedMic01,
                            tooltip: voiceTooltip,
                            onTap: onVoice,
                          ),
                  ] else
                    PillIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      tooltip: attachTooltip,
                      onTap: onPlus,
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AccentCircle(
            sending: sending,
            label: canSend ? sendLabel : attachTooltip,
            icon: canSend
                ? HugeIcons.strokeRoundedSent
                : HugeIcons.strokeRoundedAdd01,
            rotated: attachmentOpen && !canSend,
            onTap: sending ? null : (canSend ? onSend : onPlus),
          ),
        ],
      ),
    );
  }
}
