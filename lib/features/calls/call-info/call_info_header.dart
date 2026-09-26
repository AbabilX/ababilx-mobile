import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat-details/details_action_button.dart';
import '../../messages/chat_icon.dart';

/// Big avatar, the name, then Message and Talk — WhatsApp's Call info head.
/// Talk is voice only: a 1:1 call starts audio and the camera is turned on
/// from the call itself. A group has no Talk here; its calls are joined from
/// the chat.
class CallInfoHeader extends StatelessWidget {
  const CallInfoHeader({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isGroup,
    required this.messageLabel,
    required this.talkLabel,
    required this.onMessage,
    required this.onTalk,
  });

  final String name;
  final String? avatarUrl;
  final bool isGroup;
  final String messageLabel;
  final String talkLabel;
  final VoidCallback onMessage;

  /// Null while a call is already up.
  final VoidCallback? onTalk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          isGroup
              ? ClipOval(
                  child: AppAvatar(
                    size: 104,
                    url: avatarUrl,
                    name: name,
                    backgroundColor: scheme.secondaryContainer,
                    fallback: Icon(
                      Icons.groups_rounded,
                      size: 48,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                )
              : AppAvatar(size: 104, url: avatarUrl, name: name),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DetailsActionButton(
                icon: const ChatIcon(HugeIcons.strokeRoundedMessage01),
                label: messageLabel,
                onTap: onMessage,
              ),
              if (!isGroup) ...[
                const SizedBox(width: 20),
                DetailsActionButton(
                  icon: const ChatIcon(HugeIcons.strokeRoundedCall02),
                  label: talkLabel,
                  onTap: onTalk,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
