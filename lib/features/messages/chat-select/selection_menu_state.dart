import '../../jpack/data/jpack_payload.dart';
import '../chat-timeline/save_message_attachments.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/vault_placeholder.dart';
import '../tiptap_plain_text.dart';

/// Which actions the selection bar may offer, decided by the selection alone.
///
/// This is Signal's `MenuState`, and the rule that shapes it is Signal's too:
/// **the moment more than one message is selected, everything that only makes
/// sense against a single message disappears** — reply, edit and save. What
/// survives a multi-selection is forward, copy and delete.
class SelectionMenuState {
  const SelectionMenuState({
    this.reply = false,
    this.forward = false,
    this.copy = false,
    this.save = false,
    this.edit = false,
    this.delete = false,
    this.deleteForEveryone = false,
  });

  final bool reply;
  final bool forward;
  final bool copy;
  final bool save;
  final bool edit;
  final bool delete;

  /// Only the caller's own rows can go for everyone; anything can go for me.
  final bool deleteForEveryone;

  bool get isEmpty => !reply && !forward && !copy && !save && !edit && !delete;
}

/// Signal's `MAX_FORWARDABLE_COUNT`. Each destination is sealed per message on
/// this device, so a large forward is real work, not one request.
const maxForwardableMessages = 32;

SelectionMenuState selectionMenuState({
  required List<ChatMessage> selected,
  required String currentUserId,
  required bool canMessage,
}) {
  if (selected.isEmpty) return const SelectionMenuState();

  final single = selected.length == 1 ? selected.first : null;
  // A row still in flight has no server id, so nothing that names it to the
  // server — forward, delete — can run against it yet.
  final anyPending = selected.any((m) => m.isPending);
  final anyDeleted = selected.any((m) => m.isDeleted);
  // A body this device never opened would be forwarded as the vault's own
  // placeholder string, and copied as it too.
  final anySealed = selected.any(
    (m) => m.isEncrypted && isVaultPlaceholderBody(m.body),
  );
  final anyText = selected.any(
    (m) => !m.isDeleted && tiptapToPlainText(m.body).trim().isNotEmpty,
  );
  final allMine = selected.every((m) => m.userId == currentUserId);
  // A JPack is money: never forwarded, copied or edited.
  final anyJPack = selected.any((m) => JPackPayload.tryParse(m.body) != null);

  final forward =
      !anyDeleted &&
      !anyPending &&
      !anySealed &&
      !anyJPack &&
      selected.length <= maxForwardableMessages;

  return SelectionMenuState(
    reply: single != null && !anyDeleted && !anyPending && canMessage,
    forward: forward,
    copy: anyText && !anySealed && !anyJPack,
    save: single != null && canSaveMessageAttachments(single),
    edit:
        single != null &&
        allMine &&
        !anyDeleted &&
        !anyPending &&
        !anySealed &&
        !anyJPack &&
        anyText,
    // Anything can be deleted for me; only the sender's own rows for
    // everyone — the server refuses anybody else's.
    delete: !anyDeleted && !anyPending,
    deleteForEveryone: allMine && !anyDeleted && !anyPending,
  );
}
