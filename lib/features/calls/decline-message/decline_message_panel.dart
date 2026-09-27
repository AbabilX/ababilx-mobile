import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import 'decline_replies.dart';

/// "Decline with message" on the in-app ringing screen: the presets plus a
/// line to write one's own, drawn as a bottom sheet INSIDE the call screen.
///
/// Not a modal route on purpose: the call screen closes itself with a pop
/// when the caller hangs up, and a sheet route on top would take that pop
/// instead, leaving the dead call's screen behind it.
class DeclineMessagePanel extends StatefulWidget {
  const DeclineMessagePanel({
    super.key,
    required this.lang,
    required this.onPick,
    required this.onClose,
  });

  final String lang;
  final ValueChanged<String> onPick;
  final VoidCallback onClose;

  @override
  State<DeclineMessagePanel> createState() => _DeclineMessagePanelState();
}

class _DeclineMessagePanelState extends State<DeclineMessagePanel> {
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _sendCustom() {
    final text = _custom.text.trim();
    if (text.isNotEmpty) widget.onPick(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String tr(String key) => AppTranslations.of(widget.lang, key);
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;

    return Material(
      color: colors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: tr('call_decline_message_title'),
              onClose: widget.onClose,
            ),
            for (final text in DeclineReplies.presets(widget.lang))
              _ReplyTile(text: text, onTap: () => widget.onPick(text)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _custom,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: tr('call_decline_custom_hint'),
                        counterText: '',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('call_decline_send'),
                    onPressed: _custom.text.trim().isEmpty ? null : _sendCustom,
                    icon: ChatIcon(
                      HugeIcons.strokeRoundedSent,
                      color: _custom.text.trim().isEmpty
                          ? colors.onSurfaceVariant
                          : colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: ChatIcon(
              HugeIcons.strokeRoundedCancel01,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedMessage01,
              size: 20,
              color: colors.onSurface,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
