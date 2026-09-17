import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/ghost_session.dart';
import '../providers/ghost_state.dart';

/// Ghost Chat copy, with the peer's name filled in.
String ghostText(WidgetRef ref, String key, {String name = ''}) {
  final lang = ref.watch(appLanguageProvider);
  return AppTranslations.of(lang, key).replaceAll('{name}', name);
}

/// The ended screen's headline, from why it ended and who did it.
String ghostEndedTitle(WidgetRef ref, GhostState state) {
  final name = state.peerName;
  final key = switch (state.endReason) {
    GhostEndReason.burn =>
      state.endedByMe ? 'ghost_ended_burn_me' : 'ghost_ended_burn_peer',
    GhostEndReason.leave =>
      state.endedByMe ? 'ghost_ended_leave_me' : 'ghost_ended_leave_peer',
    GhostEndReason.lost => 'ghost_ended_lost',
    GhostEndReason.declined => 'ghost_ended_declined',
    GhostLocalReason.noAnswer => 'ghost_ended_no_answer',
    _ => 'ghost_ended_failed',
  };
  return ghostText(ref, key, name: name);
}

/// A server or local refusal code, phrased.
String ghostErrorText(WidgetRef ref, String code, {String name = ''}) {
  final key = switch (code) {
    'ghost_chat_busy' => 'ghost_err_busy',
    'ghost_chat_busy_self' => 'ghost_err_busy_self',
    'connection_required' ||
    'blocked' ||
    'ghost_chat_dm_only' ||
    'self_target' => 'ghost_err_connection',
    'ghost_key_unavailable' => 'ghost_err_key',
    'ghost_chat_ice_not_configured' ||
    'ghost_chat_not_found' ||
    'ghost_chat_state_conflict' => 'ghost_err_unavailable',
    'ghost_file_too_large' => 'ghost_err_file_too_large',
    _ => 'ghost_err_generic',
  };
  return ghostText(ref, key, name: name);
}
