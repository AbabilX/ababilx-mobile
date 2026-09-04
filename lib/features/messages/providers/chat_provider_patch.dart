part of 'chat_provider.dart';

mixin _ChatPatchMixin on Notifier<ChatState> {
  List<ChatConversation> patchList(
    List<ChatConversation> list,
    String id, {
    int? unreadCount,
    bool bumpUnread = false,
    String? lastMessageAt,
    String? lastMessageBody,
    String? lastMessageUserId,
    String? lastMessageAttachmentType,
    String? lastMessageAttachmentName,
    List<ChatLastAttachment>? lastMessageAttachments,
    bool clearLastMessageAttachment = false,
    bool? muted,
    String? name,
  }) {
    final next = list.map((c) {
      if (c.id != id) return c;
      var unread = c.unreadCount;
      if (unreadCount != null) unread = unreadCount;
      if (bumpUnread) unread = c.unreadCount + 1;
      return c.copyWith(
        unreadCount: unread,
        lastMessageAt: lastMessageAt,
        lastMessageBody: lastMessageBody,
        lastMessageUserId: lastMessageUserId,
        lastMessageAttachmentType: lastMessageAttachmentType,
        lastMessageAttachmentName: lastMessageAttachmentName,
        lastMessageAttachments: lastMessageAttachments,
        clearLastMessageAttachment: clearLastMessageAttachment,
        muted: muted ?? c.muted,
        name: name,
      );
    }).toList();
    return list.any((c) => c.isDm) ? sortDms(next) : sortChannels(next);
  }

  void applyIncomingMessage(
    String conversationId,
    ChatMessage msg, {
    required bool bumpUnread,
  }) {
    final atts = [
      for (final a in msg.attachments)
        ChatLastAttachment(fileName: a.fileName, contentType: a.contentType),
    ];
    final first = atts.isNotEmpty ? atts.first : null;
    state = state.copyWith(
      dms: patchList(
        state.dms,
        conversationId,
        lastMessageAt: msg.createdAt,
        lastMessageBody: msg.body,
        lastMessageUserId: msg.userId,
        lastMessageAttachmentType: first?.contentType,
        lastMessageAttachmentName: first?.fileName,
        lastMessageAttachments: atts,
        clearLastMessageAttachment: atts.isEmpty,
        bumpUnread: bumpUnread,
      ),
      channels: patchList(
        state.channels,
        conversationId,
        lastMessageAt: msg.createdAt,
        lastMessageBody: msg.body,
        lastMessageUserId: msg.userId,
        lastMessageAttachmentType: first?.contentType,
        lastMessageAttachmentName: first?.fileName,
        lastMessageAttachments: atts,
        clearLastMessageAttachment: atts.isEmpty,
        bumpUnread: bumpUnread,
      ),
    );
  }

  void upsertDm(ChatConversation dm) {
    final exists = state.dms.any((d) => d.id == dm.id);
    final merged = exists
        ? state.dms
              .map(
                (d) => d.id == dm.id
                    ? d.copyWith(
                        unreadCount: dm.unreadCount,
                        lastMessageAt: dm.lastMessageAt ?? d.lastMessageAt,
                        lastMessageBody:
                            dm.lastMessageBody ?? d.lastMessageBody,
                        lastMessageUserId:
                            dm.lastMessageUserId ?? d.lastMessageUserId,
                        lastMessageAttachmentType: dm.lastMessageAttachmentType,
                        lastMessageAttachmentName: dm.lastMessageAttachmentName,
                        lastMessageAttachments: dm.lastMessageAttachments,
                        name: dm.name,
                      )
                    : d,
              )
              .toList()
        : [dm, ...state.dms];
    state = state.copyWith(dms: sortDms(merged));
  }

  /// Folds a freshly fetched channel or group into the list.
  ///
  /// It is a merge rather than a replacement because the row this arrives from
  /// — a rename, a group-info PATCH — carries the conversation alone, without
  /// the sidebar-only fields (unread count, last message, member avatars) that
  /// only the sidebar query computes. Overwriting wholesale would blank the
  /// row's preview every time somebody changed the name.
  ///
  /// Everything a group's identity is made of has to be listed here, though:
  /// a field left out silently keeps its old value, which is how a newly
  /// uploaded photo could be saved on the server and still not appear until
  /// the app was restarted.
  void upsertChannel(ChatConversation channel) {
    final exists = state.channels.any((c) => c.id == channel.id);
    final merged = exists
        ? state.channels
              .map(
                (c) => c.id == channel.id
                    ? c.copyWith(
                        name: channel.name,
                        unreadCount: channel.unreadCount,
                        avatarUrl: channel.avatarUrl,
                        bannerUrl: channel.bannerUrl,
                        description: channel.description,
                        editInfoRole: channel.editInfoRole,
                        addMembersRole: channel.addMembersRole,
                        myRole: channel.myRole,
                      )
                    : c,
              )
              .toList()
        : [channel, ...state.channels];
    state = state.copyWith(channels: sortChannels(merged));
  }
}
