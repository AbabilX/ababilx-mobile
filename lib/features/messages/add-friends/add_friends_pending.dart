import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_friends_sheet.dart';

/// Set when a new account finishes profile setup; the chat list opens the
/// Add friends sheet once and clears it. Memory only: a kill before the
/// list paints just skips the sheet, and the chat list's own row stays.
final addFriendsAfterOnboardingProvider = StateProvider<bool>((_) => false);

/// Called by the chat list after a frame: a new account lands there straight
/// from profile setup, and its first job is to reach someone.
void offerAddFriendsIfDue(BuildContext context, WidgetRef ref) {
  if (!context.mounted || !ref.read(addFriendsAfterOnboardingProvider)) return;
  ref.read(addFriendsAfterOnboardingProvider.notifier).state = false;
  showAddFriendsSheet(context, ref);
}
