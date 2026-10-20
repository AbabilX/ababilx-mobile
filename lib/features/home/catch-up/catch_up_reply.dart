import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Set on the chat opened from a Catch up card. A sent reply drops the
/// deck and the chat and lands on Home.
const catchUpReplyQuery = 'catchUp';

String catchUpChatPath(String conversationId) =>
    '/messages/$conversationId?$catchUpReplyQuery=1';

bool chatOpenedFromCatchUp(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return false;
  return GoRouterState.of(context).uri.queryParameters[catchUpReplyQuery] ==
      '1';
}

/// A reply from a Catch up chat: the card is done, the user is on Home.
void returnHomeAfterCatchUpReply(BuildContext context) {
  if (!context.mounted || !chatOpenedFromCatchUp(context)) return;
  context.go('/home');
}
