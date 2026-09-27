import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Whether the native review screen may show its view-once eye here.
///
/// Any DM with someone else, privacy mode or not (server `MediaPolicyApplies`,
/// 2026-09-25). Not a group: an attachment has one `viewed_at`, so the first
/// member to open it would burn it for everyone. Not Note to Self: nobody to
/// hide it from.
bool viewOnceAllowed(WidgetRef ref, String conversationId) =>
    ref.read(chatProvider).conversationById(conversationId)?.hasDmPeer ?? false;

/// Wraps [onAdded] so every upload of a view-once album carries
/// `view_seconds: 0` (which also means no saving). Photos only: the eye is
/// never drawn for anything else, and a stray file stays ordinary.
ValueChanged<ChatAttachmentInput> stampViewOnce(
  bool viewOnce,
  ValueChanged<ChatAttachmentInput> onAdded,
) {
  if (!viewOnce) return onAdded;
  return (a) => onAdded(
    looksLikeImage(a.contentType, a.fileName)
        ? a.withPolicy(viewSeconds: 0, noSave: true)
        : a,
  );
}
