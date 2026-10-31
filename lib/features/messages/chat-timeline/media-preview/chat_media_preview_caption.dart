import 'package:flutter/material.dart';

/// The reference app's `ExpandingCaptionView`: two lines, tap to read the rest.
class ChatMediaPreviewCaption extends StatefulWidget {
  const ChatMediaPreviewCaption({super.key, required this.text});

  final String text;

  @override
  State<ChatMediaPreviewCaption> createState() =>
      _ChatMediaPreviewCaptionState();
}

class _ChatMediaPreviewCaptionState extends State<ChatMediaPreviewCaption> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          widget.text,
          maxLines: _open ? null : 2,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
