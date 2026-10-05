import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';

/// Shown in the composer's place while a voice note is being recorded:
/// discard on the left, the running time, send on the right.
class ShareRecordingBar extends StatefulWidget {
  const ShareRecordingBar({
    super.key,
    required this.onCancel,
    required this.onSend,
    required this.cancelLabel,
    required this.sendLabel,
  });

  final VoidCallback onCancel;
  final VoidCallback onSend;
  final String cancelLabel;
  final String sendLabel;

  @override
  State<ShareRecordingBar> createState() => _ShareRecordingBarState();
}

class _ShareRecordingBarState extends State<ShareRecordingBar> {
  final _started = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final elapsed = DateTime.now().difference(_started);
    final clock =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton(
          tooltip: widget.cancelLabel,
          onPressed: widget.onCancel,
          icon: ChatIcon(HugeIcons.strokeRoundedDelete02, color: colors.error),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            clock,
            style: TextStyle(
              fontSize: 16,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.onSurface,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: widget.sendLabel,
          onPressed: widget.onSend,
          icon: const ChatIcon(
            HugeIcons.strokeRoundedSent,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
