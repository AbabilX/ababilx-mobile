import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../settings/typing-indicators/typing_indicators_provider.dart';
import 'chat_typing_provider.dart';
import 'typing_label.dart';

/// "typing…" / "Alice is typing…" for one conversation, or '' when nobody is.
/// Rebuilds the caller only when that one conversation's typists change.
String watchTypingText(
  WidgetRef ref,
  String conversationId, {
  required bool isGroup,
}) {
  if (!ref.watch(typingIndicatorsProvider)) return '';
  final typists = ref.watch(
    chatTypingProvider.select((m) => m[conversationId]),
  );
  return typingLabel(
    typingNamesOf(typists),
    isGroup: isGroup,
    lang: ref.watch(appLanguageProvider),
  );
}
