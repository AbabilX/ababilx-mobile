import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import 'chat_provider.dart';

/// The part of [ChatState] a conversation list draws.
typedef ChatSidebarSlice = ({
  List<ChatConversation> dms,
  List<ChatConversation> channels,
  String currentUserId,
  bool sidebarLoading,
});

/// Equal (by list identity) until the sidebar itself changes. Timeline pages,
/// thread replies, search and sending all leave it alone.
ChatSidebarSlice chatSidebarSlice(ChatState state) => (
  dms: state.dms,
  channels: state.channels,
  currentUserId: state.currentUserId,
  sidebarLoading: state.sidebarLoading,
);

/// Watch this, not `chatProvider`, from anything that lists conversations.
/// The chat list and Calls stay built behind an open chat (the swipe pager
/// keeps both alive), and watching the whole state rebuilt and re-sorted
/// every row on each message page, thread reply and keystroke of search.
final chatSidebarProvider = Provider<ChatSidebarSlice>(
  (ref) => ref.watch(chatProvider.select(chatSidebarSlice)),
);
