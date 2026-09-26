import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/data/chat_client_message_id.dart';
import '../data/khaam_covers.dart';

/// Everything the compose screen shows, and nothing it merely renders.
class KhaamComposeState {
  const KhaamComposeState({
    required this.khaamId,
    required this.cover,
    this.message = '',
    this.lang = 'bn',
    this.messageIndex = 0,
    this.custom = false,
    this.busy = false,
  });

  /// Minted once per compose screen.
  final String khaamId;
  final KhaamCover cover;
  final String message;

  /// Default messages are Bangla until the user asks for English.
  final String lang;
  final int messageIndex;

  /// The user typed their own words: the dice and the language switch then
  /// leave the field alone.
  final bool custom;
  final bool busy;

  List<String> get defaults => cover.messagesFor(lang);

  String get defaultMessage =>
      defaults.isEmpty ? '' : defaults[messageIndex % defaults.length];

  /// What goes out: the typed text, or the ready-made one when left empty.
  String get outgoingMessage {
    final typed = message.trim();
    return typed.isEmpty ? defaultMessage : typed;
  }

  KhaamComposeState copyWith({
    KhaamCover? cover,
    String? message,
    String? lang,
    int? messageIndex,
    bool? custom,
    bool? busy,
  }) => KhaamComposeState(
    khaamId: khaamId,
    cover: cover ?? this.cover,
    message: message ?? this.message,
    lang: lang ?? this.lang,
    messageIndex: messageIndex ?? this.messageIndex,
    custom: custom ?? this.custom,
    busy: busy ?? this.busy,
  );
}

class KhaamComposeNotifier
    extends AutoDisposeFamilyNotifier<KhaamComposeState, KhaamCover> {
  @override
  KhaamComposeState build(KhaamCover initialCover) {
    final seed = KhaamComposeState(
      khaamId: newChatClientMessageId(),
      cover: initialCover,
    );
    return seed.copyWith(message: seed.defaultMessage);
  }

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

  void setCover(KhaamCover cover) {
    final next = state.copyWith(cover: cover, messageIndex: 0);
    state = next.custom ? next : next.copyWith(message: next.defaultMessage);
  }

  void setBusy(bool busy) => state = state.copyWith(busy: busy);
}

final khaamComposeProvider = NotifierProvider.autoDispose
    .family<KhaamComposeNotifier, KhaamComposeState, KhaamCover>(
      KhaamComposeNotifier.new,
    );

/// The gallery's search text. Keyed by `picking` because the chat's gallery
/// and the compose screen's cover picker can both be on the stack at once.
final khaamCoverQueryProvider = StateProvider.autoDispose.family<String, bool>(
  (ref, picking) => '',
);
