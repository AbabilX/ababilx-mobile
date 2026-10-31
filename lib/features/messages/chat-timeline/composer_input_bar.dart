import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'composer_format_menu.dart';
import 'composer_input_bar_buttons.dart';
import 'composer_keyboard_content.dart';
import 'composer_selection_bar.dart';

/// The reference app's composer: one pill holding the text field, camera and
/// mic, with a single accent circle beside it.
///
/// That circle is the only send affordance. It is "+" while there is nothing
/// to send and becomes the arrow the moment there is, which is also why camera
/// and mic hide at that point — the reference app keeps exactly one row and
/// swaps what sits in it rather than growing a second toolbar above the
/// keyboard.
class ComposerInputBar extends StatelessWidget {
  const ComposerInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.sending,
    required this.canSend,
    required this.attachmentOpen,
    required this.onCamera,
    required this.onVoice,
    required this.onPlus,
    required this.onSend,
    this.onSendLater,
    this.preparingVoice = false,
    this.onContentInserted,
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
  final VoidCallback onCamera;
  final VoidCallback onVoice;
  final VoidCallback onPlus;
  final VoidCallback onSend;

  /// The send arrow held down. Null for a composer that cannot schedule.
  final VoidCallback? onSendLater;

  /// A sticker or GIF from the keyboard. Null leaves the field text-only.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;
  final String cameraTooltip;
  final String voiceTooltip;
  final String attachTooltip;
  final String sendLabel;

  /// Height of the one-line pill and diameter of the circle beside it.
  static const double _size = 54;

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
              constraints: const BoxConstraints(minHeight: _size),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(_size / 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ComposerSelectionBar(
                      controller: controller,
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        contextMenuBuilder: (_, state) => composerFormatMenu(
                          pageContext: context,
                          editor: state,
                          controller: controller,
                        ),
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 17, height: 1.3),
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
                            fontSize: 17,
                            color: colors.onSurfaceVariant,
                          ),
                          // The theme fills every field with a square-cornered
                          // rectangle; the pill behind this one is the fill.
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.fromLTRB(
                            18,
                            16,
                            0,
                            16,
                          ),
                        ),
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
                      height: _size,
                      iconSize: 26,
                      tooltip: cameraTooltip,
                      onTap: onCamera,
                    ),
                    preparingVoice
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : PillIcon(
                            icon: HugeIcons.strokeRoundedMic01,
                            height: _size,
                            iconSize: 26,
                            tooltip: voiceTooltip,
                            onTap: onVoice,
                          ),
                  ] else
                    PillIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      height: _size,
                      iconSize: 26,
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
            size: _size,
            sending: sending,
            label: canSend ? sendLabel : attachTooltip,
            icon: canSend
                ? HugeIcons.strokeRoundedSent
                : HugeIcons.strokeRoundedAdd01,
            rotated: attachmentOpen && !canSend,
            onTap: sending ? null : (canSend ? onSend : onPlus),
            onLongPress: sending || !canSend ? null : onSendLater,
          ),
        ],
      ),
    );
  }
}
