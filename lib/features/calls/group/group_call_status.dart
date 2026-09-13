import '../../../core/localization/app_translations.dart';
import 'providers/group_call_state.dart';

/// One status for the full screen, minimized bar and PiP surface.
String groupCallStatus(GroupCallState state, String lang) {
  String tr(String key) => AppTranslations.of(lang, key);
  if (state.phase == GroupCallPhase.joining) return tr('group_call_joining');
  if (state.reconnecting) return tr('call_reconnecting');
  final presence = state.participants.length <= 1
      ? tr('group_call_alone')
      : tr(
          'group_call_count',
        ).replaceAll('{count}', '${state.participants.length}');
  return [
    presence,
    if (state.microphoneUnavailable)
      tr('group_call_listening')
    else if (state.muted)
      tr('group_call_muted'),
  ].join(' · ');
}

String groupCallTitle(GroupCallState state, String lang) =>
    state.title == 'Group call'
    ? AppTranslations.of(lang, 'group_call_title')
    : state.title;
