import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Text field + send. [onSend] returns true when the text was taken (the
/// field clears); false keeps it.
class SpaceComposer extends StatefulWidget {
  const SpaceComposer({super.key, required this.hint, required this.onSend});

  final String hint;
  final bool Function(String text) onSend;

  @override
  State<SpaceComposer> createState() => _SpaceComposerState();
}

class _SpaceComposerState extends State<SpaceComposer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.onSend(_text.text)) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: true,
                  fillColor: c.surfaceContainerHigh,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
              key: const Key('space-send'),
              onPressed: _send,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedSent,
                color: c.onPrimary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
