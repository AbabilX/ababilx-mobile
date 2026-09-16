import '../../../core/localization/app_translations.dart';

/// The words under a chat name while somebody is typing. A DM already names
/// its one peer, so it says only "typing…"; a group has to say who. Pure, and
/// byte-for-byte the web wording, so the two never disagree.
String typingLabel(
  List<String> names, {
  required bool isGroup,
  String lang = 'en',
}) {
  if (names.isEmpty) return '';
  String t(String key) => AppTranslations.of(lang, key);
  if (!isGroup) return t('chat_typing');
  final shown = [
    for (final n in names)
      n.trim().isEmpty ? t('chat_typing_someone') : n.trim(),
  ];
  if (shown.length == 1) {
    return t('chat_typing_one').replaceAll('{name}', shown[0]);
  }
  if (shown.length == 2) {
    return t(
      'chat_typing_two',
    ).replaceAll('{a}', shown[0]).replaceAll('{b}', shown[1]);
  }
  return t('chat_typing_many').replaceAll('{count}', '${shown.length}');
}
