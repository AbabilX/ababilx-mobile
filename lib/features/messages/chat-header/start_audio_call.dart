import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calls/providers/voice_call_provider.dart';
import '../data/models/chat_models.dart';

/// Start with audio; users can enable their camera once connected.
Future<void> startAudioCall(
  WidgetRef ref,
  ChatConversation conversation,
) async {
  if (!conversation.hasDmPeer || !conversation.canMessage) return;

  await ref
      .read(voiceCallProvider.notifier)
      .startOutgoing(conversation, video: false);
}
