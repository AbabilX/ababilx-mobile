import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_translations.dart';

/// Preset "decline with a message" replies, and how they reach the native
/// ringing screen.
///
/// The full-screen CallKit Activity (locked phone, killed app) cannot ask
/// Dart for anything, so the choices ride on the call's `extra` map when it is
/// shown. The keys here are read by `CallkitDeclineReplies.kt` and must not be
/// renamed on one side alone.
class DeclineReplies {
  const DeclineReplies._();

  static const presetKeys = [
    'call_decline_reply_busy',
    'call_decline_reply_later',
    'call_decline_reply_meeting',
    'call_decline_reply_text',
  ];

  /// Set by the native Activity on the decline event it raises.
  static const messageKey = 'decline_message';

  static const _langPref = 'call_decline_reply_lang_v1';
  static String? _rememberedLang;

  static List<String> presets(String lang) => [
    for (final key in presetKeys) AppTranslations.of(lang, key),
  ];

  /// The app's language, kept for the one place that has no profile: a call
  /// shown from a push in the background isolate. Written only on change.
  static Future<void> rememberLanguage(String lang) async {
    if (lang.isEmpty || lang == _rememberedLang) return;
    _rememberedLang = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langPref, lang);
    } catch (_) {
      // English presets are the fallback, never a blocked call.
    }
  }

  /// Read on the ring path, so it is bounded: a slow first prefs load in a
  /// fresh background isolate must never delay the call showing.
  static Future<String> language() async {
    if (_rememberedLang != null) return _rememberedLang!;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      return prefs.getString(_langPref) ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  /// Entries for a 1:1 incoming call's CallKit `extra` map. A group invite
  /// never carries them, so its ringing screen shows no Message button.
  static Future<Map<String, String>> nativeExtra() async {
    final lang = await language();
    String tr(String key) => AppTranslations.of(lang, key);
    return {
      'decline_replies': presets(lang).join('\n'),
      'decline_replies_button': tr('call_control_message'),
      'decline_replies_title': tr('call_decline_message_title'),
      'decline_replies_cancel': tr('call_decline_cancel'),
    };
  }

  /// The reply chosen on the native screen, if the decline carried one.
  static String? messageOf(Map<String, dynamic>? extra) {
    final text = extra?[messageKey]?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
