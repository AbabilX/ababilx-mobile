import '../../core/localization/app_translations.dart';
import 'providers/voice_call_state.dart';

/// The one line under the caller's name.
///
/// Pure so it can be tested without a widget tree, and so the call screen and
/// the picture-in-picture window can never disagree about what a call is
/// currently doing. That is why the language arrives as a string instead of a
/// BuildContext: a widget-bound lookup here would force every caller to be a
/// Consumer, and the return bar is rebuilt from a router listener.
String voiceCallStatusText(VoiceCallState state, {String lang = 'en'}) {
  String t(String key) => AppTranslations.of(lang, key);

  switch (state.phase) {
    case VoiceCallPhase.idle:
      return t('call_status_finished');
    case VoiceCallPhase.starting:
      return t('call_status_starting');
    case VoiceCallPhase.outgoingRinging:
      // "Calling…" until a callee device reports it is ringing.
      return state.call?.calleeRingingAt != null
          ? t('call_status_ringing')
          : t('call_status_calling');
    case VoiceCallPhase.incomingRinging:
      return t('call_status_incoming');
    case VoiceCallPhase.connecting:
      return t('call_status_securing');
    case VoiceCallPhase.connected:
      // Still "connected" during a recovery on purpose — the call has not
      // ended, it is re-gathering candidates. Showing the frozen timer instead
      // would read as a live call with dead audio.
      final since = state.reconnectingSince;
      if (since != null) return voiceReconnectText(since, lang: lang);
      return formatCallDuration(state.connectedAt);
    case VoiceCallPhase.ended:
      final status = state.call?.status;
      // Caller sees a formal busy message when the peer declines.
      if (status == 'declined' && state.outgoing) {
        return t('call_status_busy').replaceAll('{name}', state.peerName);
      }
      if (status == 'declined') return t('call_status_declined');
      if (status == 'cancelled') return t('call_status_cancelled');
      if (status == 'missed') return t('call_status_no_answer');
      final lasted = formatCallDuration(state.connectedAt);
      return lasted == '00:00'
          ? t('call_status_ended')
          : t('call_status_ended_lasted').replaceAll('{duration}', lasted);
    case VoiceCallPhase.failed:
      return t('call_status_failed');
  }
}

/// What a recovery says as it drags on.
///
/// Two minutes of an unchanging "Reconnecting…" and then a dead call reads as
/// the app hanging. Softening the wording twice tells the truth — it is still
/// trying, and it is going badly — without ending the call early or touching
/// the audio route.
String voiceReconnectText(DateTime since, {DateTime? now, String lang = 'en'}) {
  final elapsed = (now ?? DateTime.now()).difference(since);
  if (elapsed < const Duration(seconds: 15)) {
    return AppTranslations.of(lang, 'call_reconnecting');
  }
  if (elapsed < const Duration(seconds: 45)) {
    return AppTranslations.of(lang, 'call_reconnect_poor');
  }
  return AppTranslations.of(lang, 'call_reconnect_lost');
}

/// mm:ss, or hh:mm:ss once a call passes an hour. Digits only, so it needs no
/// translation.
String formatCallDuration(DateTime? started, {DateTime? now}) {
  if (started == null) return '00:00';
  final duration = (now ?? DateTime.now()).difference(started);
  final total = duration.inSeconds.clamp(0, 24 * 3600);
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (total >= 3600) {
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$hours:$m:$seconds';
  }
  return '$minutes:$seconds';
}
