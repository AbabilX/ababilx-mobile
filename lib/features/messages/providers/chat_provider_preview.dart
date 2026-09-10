part of 'chat_provider.dart';

/// Opening the chat list's sealed previews, DMs and personal groups alike.
/// The rules are pure and live in `message_e2ee/sidebar_preview.dart`.
mixin _ChatPreviewMixin on Notifier<ChatState> {
  ChatConversation visiblePreview(ChatConversation row) {
    final cutoff = ref.read(chatMessageStoreProvider).deletions;
    final at =
        DateTime.tryParse(row.lastMessageAt ?? '')?.microsecondsSinceEpoch ?? 0;
    return ref.read(messageVaultProvider).isStartingNewChat ||
            !cutoff.allowsTime(row.id, at)
        ? row.withoutMessagePreview()
        : row;
  }

  /// Opens every sealed preview in [rows] this device can open.
  ///
  /// One that will not open keeps the server's "Encrypted message", never
  /// "Unable to decrypt this message" — down a whole list that reads as lost
  /// history, and the chat list is not where a missing key is worth reporting.
  Future<List<ChatConversation>> decryptPreviews(
    List<ChatConversation> rows,
    String userId,
  ) {
    final vault = ref.read(messageVaultProvider);
    return Future.wait(
      rows.map((row) async {
        if (!hasSealedPreview(row)) return visiblePreview(row);
        final opened = await vault.decryptMessage(
          sealedPreviewMessage(row),
          userId,
        );
        return visiblePreview(
          isVaultPlaceholderBody(opened.body)
              ? row
              : row.copyWith(lastMessageBody: opened.body),
        );
      }),
    );
  }

  /// Opens the previews already on screen that still show a placeholder.
  ///
  /// This is the offline half. `fetchSidebar` opens the rows it fetches, but
  /// rows painted from disk are ciphertext-only and, with no network, no fetch
  /// ever arrives to replace them — so a phone that could read every message
  /// offline still listed each chat as "Encrypted message".
  Future<void> decryptSidebarPreviews() async {
    final notifier = this as ChatNotifier;
    if (!ref.read(messageVaultProvider).isUnlocked) return;
    final userId = await notifier.localUserId();
    if (userId.isEmpty) return;
    final sealed = [
      for (final row in [...state.dms, ...state.channels])
        if (hasSealedPreview(row) &&
            isVaultPlaceholderBody(row.lastMessageBody ?? ''))
          row,
    ];
    if (sealed.isEmpty) return;
    final opened = {
      for (final row in await decryptPreviews(sealed, userId)) row.id: row,
    };
    if (notifier.isDisposed) return;
    ChatConversation merge(ChatConversation row) {
      final next = opened[row.id];
      final text = next?.lastMessageBody ?? '';
      if (next == null || isVaultPlaceholderBody(text)) return row;
      if (!previewStillCurrent(row, next)) return row;
      return row.copyWith(lastMessageBody: text);
    }

    state = state.copyWith(
      dms: state.dms.map(merge).toList(),
      channels: state.channels.map(merge).toList(),
    );
  }

  /// Opens the cached list's previews on a cold start, before any request.
  ///
  /// The identity comes from secure storage here instead of waiting on
  /// bootstrap's network restore: offline that is the only restore there is,
  /// and online it would hold the list on placeholders for a round trip.
  Future<void> openCachedPreviews() async {
    final vault = ref.read(messageVaultProvider);
    if (!vault.isUnlocked && !await vault.restoreTrustedIdentityOffline()) {
      return;
    }
    await decryptSidebarPreviews();
  }
}
