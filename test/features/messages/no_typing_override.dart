import 'package:ababilx/features/messages/chat-typing/chat_typing_provider.dart';
import 'package:ababilx/features/settings/typing-indicators/typing_indicators_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Typing, quiet: the switch answers "on" (the server default) without the
/// request it makes when first read, and the typist map starts empty without
/// the one-second prune timer. Every timeline and chat row reads both, and a
/// widget test that is not about typing must not leave either running.
final List<Override> noTypingOverrides = [
  typingIndicatorsProvider.overrideWith(_FixedSwitch.new),
  chatTypingProvider.overrideWith(_NoTypists.new),
];

class _FixedSwitch extends TypingIndicatorsNotifier {
  @override
  bool build() => true;
}

class _NoTypists extends ChatTypingNotifier {
  @override
  Map<String, Map<String, Typist>> build() => const {};
}
