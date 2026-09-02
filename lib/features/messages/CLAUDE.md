# Mobile chat — outgoing message identity

Settled 2026-09-03. Do not rework the send reconciliation without reading this.

## The one rule

`clientRef` (`client_message_id`) is the stable **local** row key from the
moment a send is tapped until it is confirmed. The server id rides in the
payload. Reconciliation is an in-place update. Never delete-by-clientRef.

The server echoes `client_message_id` back on every confirmed message
(`ChatMessage.ClientMessageID`). Matching a pending bubble by `m.clientRef`
therefore also matches the settled row and empties the timeline — while the
chat-list preview (patched separately by `applyIncomingMessage`) stays correct.

Signal does the same: `MessageTable.insertMessageOutbox` then `markAsSent` on
that row. Insert-then-update, never delete-and-reinsert.

## What must stay true

- `_replacePendingMessage` identifies the pending bubble by **row id**
  (`m.id == clientRef && m.id != confirmed.id`).
- `canonicalChatMessages` treats same server id, same `clientRef`, and a
  pending row id that equals the other copy's `clientRef` as **one** message.
  A websocket copy that echoes `client_message_id` and a history-page copy
  that omitted it must not both stay on screen.
- History store accepts unsent rows. `persistOutbox` (after `encryptNew`)
  writes the ciphertext-only copy for a DM. `searchText` is empty while
  `isPending`.
- Confirm writes the same local key (`localMessageRowId` = clientRef when
  present). Absent `send_status` in JSON still means `sent`.
- `_markPendingFailed` only patches a still-pending row (`m.id == pendingId &&
  m.isPending`), so a lost HTTP response after a websocket confirm cannot flip
  the settled bubble to failed.

Web is unaffected: it has no delete-by-clientRef path.
