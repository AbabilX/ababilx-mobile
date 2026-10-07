import 'dart:convert';

/// The longest text one message may carry: 6000 words.
///
/// Words are what a person can count; the server cannot (a sealed body is
/// ciphertext to it) and bounds bytes instead — `MaxChatBodyLen`, 256 KiB of
/// TipTap JSON. [maxMessageBodyBytes] sits under that, so a body this file
/// accepts is never refused there.
const maxMessageWords = 6000;
const maxMessageBodyBytes = 250 * 1024;

final _wordBreak = RegExp(r'\s+');

int countMessageWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return _wordBreak.allMatches(trimmed).length + 1;
}

/// [plain] is what the person typed, [encoded] the body about to be sent.
bool isMessageTooLong(String plain, {String? encoded}) =>
    countMessageWords(plain) > maxMessageWords ||
    utf8.encode(encoded ?? plain).length > maxMessageBodyBytes;

String messageTooLongText(String language) => language == 'bn'
    ? 'বার্তাটি অনেক বড়। সর্বোচ্চ ৬০০০ শব্দ পাঠানো যায়। '
          'বড় লেখার জন্য স্নিপেট ব্যবহার করুন।'
    : 'This message is too long. The limit is 6000 words. '
          'Use a snippet for long text.';
