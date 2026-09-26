import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../messages/providers/chat_provider.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/voice_call_provider.dart';

/// Redial a 1:1 call when the conversation is still in the sidebar;
/// otherwise just open it, which is also the only sane action for a group.
/// Shared by the call log row and the Call info page.
void redialCall(
  BuildContext context,
  WidgetRef ref,
  String conversationId, {
  required bool isGroup,
}) {
  final conversation = ref.read(chatProvider).conversationById(conversationId);
  if (!isGroup && conversation != null && conversation.isDm) {
    // UI already nulls the button while busy; keep the hard gate so a stale
    // callback cannot start a second call underneath the first.
    if (ref.read(voiceCallProvider).active ||
        ref.read(groupCallProvider).active) {
      return;
    }
    ref.read(voiceCallProvider.notifier).startOutgoing(conversation);
    return;
  }
  context.push('/messages/$conversationId');
}
