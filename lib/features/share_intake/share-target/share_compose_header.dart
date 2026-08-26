import 'package:flutter/material.dart';

import '../data/shared_payload.dart';
import 'share_payload_preview.dart';

/// Top of the share screen: what is being sent, then the message that goes
/// with it.
///
/// The caption is a plain field rather than the chat composer — the composer
/// owns uploads, mentions, voice and reply state, none of which apply to a
/// share that has not chosen a conversation yet.
class ShareComposeHeader extends StatelessWidget {
  const ShareComposeHeader({
    super.key,
    required this.payload,
    required this.caption,
    required this.enabled,
    required this.onChanged,
  });

  final SharedPayload payload;
  final TextEditingController caption;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SharePayloadPreview(payload: payload),
        TextField(
          controller: caption,
          enabled: enabled,
          minLines: 1,
          maxLines: 4,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Add a message',
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            border: InputBorder.none,
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
