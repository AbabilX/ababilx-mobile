import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/chat_client_message_id.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_money.dart';

/// Everything the compose screen shows, and nothing it merely renders.
class JPackComposeState {
  const JPackComposeState({
    required this.jpackId,
    required this.cover,
    this.amountText = '',
    this.message = '',
    this.lang = 'bn',
    this.messageIndex = 0,
    this.custom = false,
    this.busy = false,
  });

  /// One id however many times Pay is pressed, so a retry after an error can
  /// never charge twice.
  final String jpackId;
  final JPackCover cover;
  final String amountText;
  final String message;

  /// Default messages are Bangla until the user asks for English.
  final String lang;
  final int messageIndex;

  /// The user typed their own words: the dice and the language switch then
  /// leave the field alone.
  final bool custom;
  final bool busy;

  double? get amount {
    final v = double.tryParse(amountText.trim());
    return v == null || v <= 0 ? null : v;
  }

  List<String> get defaults => cover.messagesFor(lang);

  String get defaultMessage =>
      defaults.isEmpty ? '' : defaults[messageIndex % defaults.length];

  /// What goes out: the typed text, or the ready-made one when left empty.
  String get outgoingMessage {
    final typed = message.trim();
    return typed.isEmpty ? defaultMessage : typed;
  }

  JPackAmountProblem? problem(double balance) {
    final a = amount;
    if (a == null) return null;
    if (a > jpackMaxAmount) return JPackAmountProblem.overMax;
    if (a > balance) return JPackAmountProblem.overBalance;
    return null;
  }

  JPackComposeState copyWith({
    JPackCover? cover,
    String? amountText,
    String? message,
    String? lang,
    int? messageIndex,
    bool? custom,
    bool? busy,
  }) => JPackComposeState(
    jpackId: jpackId,
    cover: cover ?? this.cover,
    amountText: amountText ?? this.amountText,
    message: message ?? this.message,
    lang: lang ?? this.lang,
    messageIndex: messageIndex ?? this.messageIndex,
    custom: custom ?? this.custom,
    busy: busy ?? this.busy,
  );
}

enum JPackAmountProblem { overMax, overBalance }

class JPackComposeNotifier
    extends AutoDisposeFamilyNotifier<JPackComposeState, JPackCover> {
  @override
  JPackComposeState build(JPackCover initialCover) {
    final seed = JPackComposeState(
      jpackId: newChatClientMessageId(),
      cover: initialCover,
    );
    return seed.copyWith(message: seed.defaultMessage);
  }

  void setAmountText(String text) => state = state.copyWith(amountText: text);

  void typeMessage(String text) =>
      state = state.copyWith(message: text, custom: text.trim().isNotEmpty);

  /// Next ready-made message. Replaces whatever was typed — that is the ask.
  void shuffle() {
    final next = state.copyWith(
      messageIndex: state.messageIndex + 1,
      custom: false,
    );
    state = next.copyWith(message: next.defaultMessage);
  }

  void setLang(String lang) {
    if (lang == state.lang) return;
    final next = state.copyWith(lang: lang);
    state = next.custom ? next : next.copyWith(message: next.defaultMessage);
  }

  void setCover(JPackCover cover) {
    final next = state.copyWith(cover: cover, messageIndex: 0);
    state = next.custom ? next : next.copyWith(message: next.defaultMessage);
  }

  void setBusy(bool busy) => state = state.copyWith(busy: busy);
}

final jpackComposeProvider = NotifierProvider.autoDispose
    .family<JPackComposeNotifier, JPackComposeState, JPackCover>(
      JPackComposeNotifier.new,
    );

/// The gallery's search text. Keyed by `picking` because the chat's gallery
/// and the compose screen's cover picker can both be on the stack at once.
final jpackCoverQueryProvider = StateProvider.autoDispose.family<String, bool>(
  (ref, picking) => '',
);
