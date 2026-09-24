import '../data/group_call_api.dart';

/// Mirrors web `group-call-state.ts: groupCallErrorMessage`.
String groupCallErrorMessage(Object error) {
  if (error is GroupCallApiException) {
    switch (error.code) {
      case 'group_call_user_busy':
        return 'You are already in another call.';
      case 'group_call_full':
        return 'This group call is full.';
      case 'group_calls_not_configured':
        return 'Group calls are not available yet.';
      case 'group_calls_channel_only':
        return 'Group calls only work in channels.';
      // Group member permissions (server 0157).
      case 'call_start_restricted':
        return 'Admins don\'t allow you to start calls in this group.';
      case 'member_restricted':
        return 'Admins restricted you from this group\'s calls.';
    }
  }
  return 'Could not join the group call.';
}

String groupScreenShareErrorMessage(Object error) {
  if (error is GroupCallApiException &&
      error.code == 'group_screen_share_busy') {
    return 'Someone else is already sharing a screen.';
  }
  if (error is StateError && error.message.contains('permission denied')) {
    return 'Screen sharing was cancelled.';
  }
  return 'Could not change screen sharing.';
}
