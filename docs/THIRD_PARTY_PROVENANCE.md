# Third-party design and code provenance

Source comments in `lib/` and `test/` no longer name the reference apps they
were modelled on. This file keeps the record those comments held, as it
stood on 2026-10-31 (branch `chore/neutral-ui-names`), so it is clear which
files describe themselves as ports of, or as following, Signal (AGPLv3:
Signal-Android, Signal-Desktop) code or behaviour.

Keep this file. A file listed here that says it "ports" a named class or
method is a candidate for a clean-room rewrite or for AGPL compliance;
renaming it does not change its licence status.

245 files, 365 lines.

## `lib/core/launch/launch_hold.dart`

- L8: /// Signal's launch: the system splash (icon on the app's background) stays

## `lib/core/localization/app_translations.dart`

- L1224: // Signal's "(3) Missed · 4:12" — the count prefixes the state, and the

## `lib/core/network/ws_client.dart`

- L50: /// Signal's keepalive, expressed as one property.
- L54: /// died under us into an `onDone` this client can reconnect from. Signal

## `lib/core/network/ws_client_background.dart`

- L5: /// Signal keeps its websocket for two minutes after the app leaves the screen

## `lib/core/network/ws_client_revive.dart`

- L15: /// Signal's `IncomingMessageObserver` wakes its connect loop for: the app

## `lib/core/network/ws_link_watch.dart`

- L20: /// Signal's `IncomingMessageObserver` wakes its connect loop on exactly these:

## `lib/core/router/app_router.dart`

- L258: // Signal's Data and storage, and the screens under it.
- L321: // Signal's conversation settings. Declared before '/messages/:id' for

## `lib/features/attachments/services/attachment_adopter.dart`

- L29: /// Signal does the same thing from the other end: an outgoing attachment is

## `lib/features/auth/data/account_data_wiper.dart`

- L18: /// Signal-style account switch: remove everything private to the old account,

## `lib/features/auth/providers/auth_provider.dart`

- L189: // Stop work from this session, but keep this phone's Signal-style archive.

## `lib/features/calls/audio/call_audio_devices.dart`

- L10: /// port of Signal's `SignalAudioManager`). Commands go down; every change of
- L62: /// Signal's `SetDefaultDevice`.
- L71: /// Signal's `SetUserDevice` with a picker row's id.

## `lib/features/calls/audio/call_audio_output.dart`

- L1: /// Where a call's audio is going — Signal's `WebRtcAudioOutput` plus
- L21: /// One row of the picker — Signal's `AudioOutputOption`. [id] goes back to
- L67: /// Signal's `SHOW_PICKER_THRESHOLD`: with fewer choices the button cycles.
- L76: /// Signal's `willDisplayPicker`: three or more outputs, or no earpiece to
- L84: /// when the current is unknown — the first that is not it (Signal's

## `lib/features/calls/audio/call_audio_route.dart`

- L17: /// **Android: one native owner, Signal's way.** `CallAudioSession.kt` ports
- L18: /// Signal-Android's `SignalAudioManager`: it holds mode, focus and the
- L22: /// Answer) it reports Telecom's routes and asks Telecom, as Signal's
- L43: /// Starts a DM call's audio session — Signal's Initialize + SetDefaultDevice
- L75: /// The camera came on: Signal's `enableSpeakerPhoneIfNeeded` — a call on

## `lib/features/calls/calls-list/call_log_cluster.dart`

- L21: /// Signal's call-log clustering (`CallEventCache.readNextCallLog`), with our
- L26: /// lead on **who**, on **direction**, and on **missed-ness** — Signal's
- L33: /// row's own timestamp. Signal uses four hours; ours is one, which is the

## `lib/features/calls/calls-list/call_log_format.dart`

- L6: /// Arrow that says which way the call went, Signal-style: missed calls get the

## `lib/features/calls/calls-list/call_log_row.dart`

- L10: /// [count] is how many calls this row stands for. Signal prints it in front of

## `lib/features/calls/data/restored_call_log.dart`

- L11: /// Call history brought back from a local backup — Signal's call log lives on

## `lib/features/calls/group/providers/group_call_provider.dart`

- L178: // Android: the call's audio belongs to the native owner (Signal's
- L179: // SignalAudioManager), loudspeaker by default, a headset ahead of it.

## `lib/features/calls/live_call.dart`

- L4: /// The call this phone is in, for Signal's busy rule — or null when idle.
- L6: /// Signal accepts a new incoming call only from `IdleActionProcessor`; every

## `lib/features/calls/native/android_call_params.dart`

- L17: /// Signal's `CallStyle` shape, a chronometer, and a Hang up wired straight

## `lib/features/calls/native/android_call_ringback.dart`

- L10: /// Signal's `OutgoingRinger` (looping MediaPlayer on the voice-communication

## `lib/features/calls/native/android_call_ui.dart`

- L99: // Signal's busy rule: only an idle phone rings. A phone placing,

## `lib/features/calls/native/android_group_call_ui.dart`

- L159: // Busy: a phone already in a call never rings (Signal's idle-only rule).

## `lib/features/calls/native/android_ongoing_call.dart`

- L16: /// after Signal's ongoing-call notification — tap the body to return, press

## `lib/features/calls/native/android_pip.dart`

- L6: /// Picture-in-picture, Signal's answer to "I left the call screen".
- L8: /// Signal's call Activity shrinks into a floating window on back or Home

## `lib/features/calls/native/android_screen_share.dart`

- L18: /// other. Signal runs one service for the whole call and ORs the projection

## `lib/features/calls/native/background_voice_call_gate.dart`

- L47: // Busy (Signal's idle-only rule): this phone is already in a call — the

## `lib/features/calls/native/incoming_call_admission.dart`

- L10: /// Signal-style admission: an offer cannot ring while an existing call is

## `lib/features/calls/ongoing_call_sync.dart`

- L207: /// The screen blanks at the ear — Signal's `LockManager` `IN_CALL`: an
- L208: /// outgoing call from the moment it rings (Signal enters `IN_CALL` then),
- L210: /// that is a call the user is looking at. Video on either side is Signal's
- L234: /// Signal's busy rule, told to the process: entering a call stops every

## `lib/features/calls/screens/incoming_call_view.dart`

- L10: /// The ringing screen — Signal's `IncomingCallScreen`, and the ONLY one.
- L12: /// Signal has one call Activity; its ringing notification opens it, and it
- L18: /// Layout, Signal's numbers: the caller's photo blurred edge to edge under a
- L23: /// Message (decline with a text) and Silence are ours, not Signal's. They sit
- L24: /// where Signal puts its one secondary action ("Answer without video"): a
- L162: // Signal: the header hangs from the top, a weighted spacer

## `lib/features/calls/screens/voice_call_screen.dart`

- L29: /// picture-in-picture window any more. Signal can do that because its call

## `lib/features/calls/webrtc/voice_peer_engine.dart`

- L208: // a connected Bluetooth or wired headset ahead of both, as in Signal —

## `lib/features/calls/widgets/active_call_banner.dart`

- L13: /// The bar Signal and WhatsApp show across the top of the app while a call is

## `lib/features/calls/widgets/call_audio_dropdown.dart`

- L3: /// Signal's drop-down triangle on the audio button: shown when a press opens

## `lib/features/calls/widgets/call_audio_labels.dart`

- L5: /// Icons and names for call audio outputs — Signal's `WebRtcAudioOutput`
- L23: /// A row's name, Signal's `toFriendlyName`: a Bluetooth device by its own name.

## `lib/features/calls/widgets/call_audio_output_sheet.dart`

- L11: /// The audio-output button's behaviour — Signal's `CallAudioToggleButton` +
- L57: // The icon is where the sound is now. Signal keeps the speaker glyph on
- L75: /// Signal's `WebRtcAudioOutputBottomSheet`: "Audio output", then one radio

## `lib/features/calls/widgets/call_backdrop.dart`

- L9: /// Signal blurs the caller's own photo across the whole window and lays a

## `lib/features/calls/widgets/call_control_button.dart`

- L21: /// The larger 78dp size Signal gives Answer and Decline, where the button is

## `lib/features/calls/widgets/call_controls_row.dart`

- L22: /// The audio seat is Signal's `CallAudioToggleButton`: earpiece ↔ speaker

## `lib/features/calls/widgets/call_network_badge.dart`

- L9: /// Signal bars and a word for the 1:1 call's network.

## `lib/features/calls/widgets/call_return_bar.dart`

- L7: /// WhatsApp and Signal both keep the call *legible* from outside it: the bar
- L39: /// enough, the way Signal reddens its own bar.

## `lib/features/calls/widgets/call_ring_pulse.dart`

- L5: /// Signal's incoming screen keeps one moving element while the phone rings, so

## `lib/features/calls/widgets/call_top_bar.dart`

- L4: /// carries the same soft drop shadow Signal uses rather than relying on the
- L12: /// Signal draws it as a 240dp black→transparent gradient rather than a solid

## `lib/features/calls/widgets/call_video_view.dart`

- L27: /// far as Signal crops it and letterboxed for the rest.

## `lib/features/calls/widgets/incoming_call_buttons.dart`

- L6: /// Signal's `webrtc_hangup_background` / `webrtc_answer_background`.
- L10: /// One button of Signal's ringing screen with its label underneath
- L15: /// (Signal's `AnswerWithoutVideoButtonAndLabel`), so every label in a row

## `lib/features/calls/widgets/incoming_call_header.dart`

- L8: /// The top half of Signal's `IncomingCallScreen`, top to bottom: which kind of
- L12: /// Signal puts its logo before the kind label; this app can wear a disguise
- L50: // Signal: 22 above / 30 below in portrait, 0 / 20 in landscape.

## `lib/features/calls/widgets/local_camera_preview.dart`

- L8: /// where Signal and every dialler put it, so the control sits on the thing

## `lib/features/calls/widgets/pip_call_view.dart`

- L8: /// A floating window is roughly the size of a business card, so Signal strips

## `lib/features/calls/widgets/video_fit.dart`

- L5: /// libwebrtc's `RendererCommon.getDisplaySize`, in Dart — the rule Signal uses
- L26: // and Signal treats it the same way.

## `lib/features/ghost/native/ghost_blobs.dart`

- L9: /// descriptor — Signal's memory-blob model. Only the viewer the user picks

## `lib/features/ghost/protocol/ghost_cluster.dart`

- L7: /// Signal's rule, and the same one `chatMessageClusterPosition` applies: the

## `lib/features/ghost/widgets/ghost_bubble.dart`

- L97: /// Signal's footer, minus everything a Ghost Chat has no state for: the time,

## `lib/features/local-backup/extras/backup_extras_export.dart`

- L19: /// What Signal's backup carries beside messages: the call log, settings,

## `lib/features/local-backup/extras/backup_prefs.dart`

- L8: /// The app settings a backup carries — Signal's backup restores the person's

## `lib/features/local-backup/local_backup_state.dart`

- L27: /// list's "Restoring · 236 KB of 1.6 MB" (Signal's restore banner).

## `lib/features/local-backup/ui/local_backup_restore_banner.dart`

- L10: /// Signal's restore banner over the chat list: a rounded pill with a history

## `lib/features/local-backup/ui/local_backup_restore_flow.dart`

- L90: /// Signal's way: the restore runs behind the chat list, shown by the banner

## `lib/features/messages/archive/archive_frames.dart`

- L12: /// error. Signal needs a protobuf schema because five clients in three

## `lib/features/messages/archive/archive_importer.dart`

- L16: /// Signal's import wipes first because it restores a whole database including

## `lib/features/messages/chat-date-divider/index.dart`

- L4: /// Signal's day marker: centred, small, and set on a chip once a wallpaper is

## `lib/features/messages/chat-details/conversation_details_screen.dart`

- L23: /// Signal's conversation settings: a full screen, reached by tapping the name

## `lib/features/messages/chat-details/details_action_button.dart`

- L5: /// Signal draws these as a filled square with the label under it, not as an

## `lib/features/messages/chat-details/details_header.dart`

- L34: /// row of square actions. Signal puts the name itself on a chevron for a 1:1

## `lib/features/messages/chat-details/details_tile.dart`

- L4: /// underneath. Signal states the current value as the subtitle ("Off", "On")
- L55: /// The hairline between two groups of rows. Signal separates sections with a

## `lib/features/messages/chat-details/groups_in_common_section.dart`

- L9: /// Signal's "N groups in common" block on a person's profile: the groups you

## `lib/features/messages/chat-details/report_spam_action.dart`

- L13: /// Signal's "Report spam", offered beside Block and deliberately separate from

## `lib/features/messages/chat-details/shared_media_section.dart`

- L10: /// Signal's "Shared media": a strip of the newest files in this conversation

## `lib/features/messages/chat-header/index.dart`

- L86: // Signal: the name is a link to the conversation's own settings

## `lib/features/messages/chat-list/chat_search_matches.dart`

- L8: /// Signal-Android's list search puts this section first

## `lib/features/messages/chat-list/chat_search_results.dart`

- L17: /// Signal-Android order: name-matched chats, then message keyword hits.

## `lib/features/messages/chat-list/chat_search_section_header.dart`

- L3: /// Signal's search section label (`contact_search_section_header`: 16/12 pad,

## `lib/features/messages/chat-list/conversation_actions_sheet.dart`

- L20: /// Signal's long press, as a sheet for the row that was pressed rather than an

## `lib/features/messages/chat-list/conversation_avatar.dart`

- L43: // their own presence dot on it would be the avatar. Signal draws a

## `lib/features/messages/chat-list/conversation_row.dart`

- L36: /// Signal's gesture: press and hold a row for what can be done to it.
- L206: // Signal puts the pin where the unread badge goes and

## `lib/features/messages/chat-list/conversation_rows.dart`

- L41: /// Signal's gesture: press and hold a row for what can be done to it.

## `lib/features/messages/chat-list/preview_file_badge.dart`

- L16: /// as Signal's list does: a camera file name ("Photo on 18-7-2…") tells the

## `lib/features/messages/chat-mute/mute_flow.dart`

- L11: /// press). Muted → unmute at once, Signal's arrangement: there is nothing to

## `lib/features/messages/chat-mute/mute_options_sheet.dart`

- L8: /// Signal's mute choices as one bottom sheet: four lengths, Always, Only

## `lib/features/messages/chat-recipient-picker/chat_recipient_eligible.dart`

- L12: /// chat just written in sat below them. Signal and WhatsApp offer the most

## `lib/features/messages/chat-recipient-picker/chat_recipient_sections.dart`

- L28: /// The idle list is Signal's: the newest few chats, then the groups below

## `lib/features/messages/chat-recipient-picker/chat_recipient_target.dart`

- L8: /// A destination in the shared Signal-style picker.

## `lib/features/messages/chat-select/message_selection.dart`

- L5: /// Signal keeps this on the conversation adapter; here it is a provider so the
- L59: /// device, or one that expired out of the feed. Signal does the same on

## `lib/features/messages/chat-select/selectable_message_row.dart`

- L7: /// Signal's numbers, from `MultiselectItemDecoration`: the row's content is
- L31: /// The gutter Signal shifts content to while selecting.
- L42: // Signal: transparent black over a wallpaper, transparent white in dark
- L121: // Signal's unselected ring: 1.5dp, and deliberately faint

## `lib/features/messages/chat-select/selection_actions.dart`

- L20: /// Builds the bars' buttons in Signal's order — Reply, Forward, Save, Copy,
- L23: /// Every action closes the mode when it is done, which is Signal's
- L117: /// Signal's `copyToClipboard`, which sorts by date and joins the bodies.

## `lib/features/messages/chat-select/selection_menu_state.dart`

- L9: /// This is Signal's `MenuState`, and the rule that shapes it is Signal's too:
- L37: /// Signal's `MAX_FORWARDABLE_COUNT`. Each destination is sealed per message on

## `lib/features/messages/chat-timeline/attachment_album_geometry.dart`

- L106: /// Outer corners of the album block only — matches Signal's outline rounding.

## `lib/features/messages/chat-timeline/attachment_gallery.dart`

- L17: /// The chat album viewer — Signal-Android's `MediaPreviewFragment`.

## `lib/features/messages/chat-timeline/attachment_video_tile.dart`

- L12: /// A video in a bubble, held to the same bounds as a photo — Signal sizes both
- L33: /// Text under the clip: Signal's wider floor, so the caption is not

## `lib/features/messages/chat-timeline/bubble_metrics.dart`

- L5: /// Signal's own conversation-item measurements, in logical pixels (Android dp
- L115: /// Gap above a row. Signal collapses it to 1 inside a cluster and keeps 8

## `lib/features/messages/chat-timeline/bubble_side_indicators.dart`

- L13: /// no scope and so draws none, which is Signal's rule for both.
- L34: /// Signal's `quoted_indicator`: a 32dp circle beside the bubble, on the side
- L64: // Signal hides it while messages are being picked out.
- L135: /// Signal's `QUOTED_ALPHA_INTERPOLATOR`: gone by a third of the way to the

## `lib/features/messages/chat-timeline/chat_timeline_older.dart`

- L11: /// Signal keeps three pages loaded either side of what is on screen; this

## `lib/features/messages/chat-timeline/chat_timeline_selection.dart`

- L10: /// another device, or one that fell out of the loaded page. Signal does the

## `lib/features/messages/chat-timeline/composer.dart`

- L388: /// GIF, which goes out the moment it is inserted, as on Signal and
- L496: // Keep this compose session focused, matching Signal's continuous-send UX.

## `lib/features/messages/chat-timeline/composer_attachment_keyboard.dart`

- L10: /// Signal's attachment keyboard: your recent media in a strip, and the

## `lib/features/messages/chat-timeline/composer_input_bar.dart`

- L9: /// Signal's composer: one pill holding the text field, camera and mic,
- L14: /// and mic hide at that point — Signal keeps exactly one row and swaps what

## `lib/features/messages/chat-timeline/composer_media_rail.dart`

- L9: /// keyboard, the way Signal opens straight onto your last photos instead of

## `lib/features/messages/chat-timeline/composer_pending_previews.dart`

- L10: /// Order matters: it is the order they arrive in the thread. Signal lets you

## `lib/features/messages/chat-timeline/composer_reply_target.dart`

- L8: /// a preview of what it answers, like Signal. Inside a thread sheet the reply

## `lib/features/messages/chat-timeline/group_event_row.dart`

- L8: /// changes and the like. Not a chat bubble; mirrors WhatsApp/Signal and web

## `lib/features/messages/chat-timeline/long_message_screen.dart`

- L14: /// The whole of a message that was too long for its bubble — Signal's

## `lib/features/messages/chat-timeline/media-preview/chat_media_preview_caption.dart`

- L3: /// Signal's `ExpandingCaptionView`: two lines, tap to read the rest.

## `lib/features/messages/chat-timeline/media-preview/chat_media_preview_meta.dart`

- L5: /// Who sent the media and what they wrote — Signal's toolbar + caption.

## `lib/features/messages/chat-timeline/media-preview/chat_media_preview_rail.dart`

- L9: /// Signal's album rail: 46dp cells, 8dp corners, the current one ringed.

## `lib/features/messages/chat-timeline/media_caption_layout.dart`

- L5: /// bubble's width and the caption wraps to it — Signal's arrangement.

## `lib/features/messages/chat-timeline/media_frame.dart`

- L37: // Signal floor: very wide files stay full width and crop into min height.

## `lib/features/messages/chat-timeline/message_attachments.dart`

- L33: /// edge-to-edge shape but takes Signal's wider floor, since the caption

## `lib/features/messages/chat-timeline/message_bubble.dart`

- L8: /// **Both sides share one fill, deliberately.** Signal paints the outgoing
- L14: /// The surface does get more opaque once a wallpaper is set — Signal's own
- L41: /// One message bubble: Signal's rounded rectangle, its collapsed corner facing
- L60: /// Sending bubbles fade, exactly as Signal dims an unsent item.

## `lib/features/messages/chat-timeline/message_bubble_content.dart`

- L254: /// Quote, then the card, then the author's own text under it — Signal's

## `lib/features/messages/chat-timeline/message_bubble_footer.dart`

- L13: /// Time and delivery state, inside the bubble on its last line — where Signal

## `lib/features/messages/chat-timeline/message_link_preview.dart`

- L11: /// Signal-Android's link preview, inside the bubble.
- L20: /// The card takes no colour of its own. Signal paints it with the bubble's own
- L41: /// Signal's `MessageRecordUtil.hasBigImageLinkPreview`.

## `lib/features/messages/chat-timeline/message_long_body.dart`

- L6: /// Signal never lets a bubble grow without a limit. A body past
- L7: /// `SignalServiceMessageLimits.MAX_INLINE_BODY_SIZE_BYTES` is split when it is
- L21: /// A little under Signal's 2 KB inline body — ours is measured in characters
- L67: /// Signal's "Read More". It opens the message full screen rather than growing

## `lib/features/messages/chat-timeline/message_menu.dart`

- L34: /// Signal's long-press overlay: the message lifted out of the list over a
- L105: /// A dialog route with Signal's two clocks: the staggered reveal on the way
- L107: /// its own — the surface paints the shade, which Signal shows at full strength

## `lib/features/messages/chat-timeline/message_menu_focus.dart`

- L33: // the real bubble is about to reappear — Signal's hide animates the
- L40: // overlay needs it, unpinching from Signal's 0.95 press scale on
- L82: // Signal moves a bitmap. A boundary is the same bargain: the message

## `lib/features/messages/chat-timeline/message_menu_geometry.dart`

- L21: /// Final rect of the lifted message. Signal moves the bubble out of the
- L30: /// Signal reverses the item order when the menu opens upwards, so the row
- L35: /// Ports Signal's `ConversationReactionOverlay#showAfterLayout` placement.

## `lib/features/messages/chat-timeline/message_menu_items.dart`

- L14: /// Signal's own order: Reply, Forward, Save, Copy, then the rest, with the
- L59: // Signal puts multi-select right after the per-message actions and before
- L88: /// The panel is `wrap_content` with a 200dp floor in Signal, so the width has

## `lib/features/messages/chat-timeline/message_menu_metrics.dart`

- L1: /// Signal's own measurements for the long-press overlay, in logical pixels
- L17: /// Gap Signal leaves between the bubble and the bar it floats above.

## `lib/features/messages/chat-timeline/message_menu_panels.dart`

- L11: /// Signal's reveal.
- L30: /// Signal's default six, in Signal's order.

## `lib/features/messages/chat-timeline/message_menu_pointer.dart`

- L6: /// Signal keeps receiving MotionEvents on the conversation list and forwards

## `lib/features/messages/chat-timeline/message_menu_shade.dart`

- L5: /// Signal's shade is there in full from the first frame and only fades on the

## `lib/features/messages/chat-timeline/message_menu_surface.dart`

- L59: // ViewPropertyAnimator's default, which carries Signal's snapshot.
- L99: // Signal ticks once per emoji entered, never on leaving one.

## `lib/features/messages/chat-timeline/message_menu_timeline.dart`

- L5: /// One piece of Signal's reveal, cut out of the route's single animation.
- L7: /// Signal runs every piece on its own 200ms tween with its own start delay

## `lib/features/messages/chat-timeline/message_press_pinch.dart`

- L5: /// The pinch a bubble takes while a finger rests on it — Signal's

## `lib/features/messages/chat-timeline/message_quote_block.dart`

- L11: /// Signal's quote block: the message being answered, inset at the top of the

## `lib/features/messages/chat-timeline/message_request_bar.dart`

- L8: /// Signal's message-request prompt: it takes the composer's place at the

## `lib/features/messages/chat-timeline/message_row.dart`

- L159: // while selecting — Signal's `SwipeAvailabilityProvider` checks
- L199: // Signal hides the original under its lifted copy.

## `lib/features/messages/chat-timeline/message_row_content.dart`

- L23: /// Signal's conversation item: your messages right, theirs left, avatars only

## `lib/features/messages/chat-timeline/message_row_gestures.dart`

- L4: /// Signal's gestures on a message row: a hold opens the menu, a double tap
- L9: /// picks the row instead, as a tap does — Signal's action mode.
- L30: /// A finger settled on the row (true, 100ms after touch-down — Signal's

## `lib/features/messages/chat-timeline/message_swipe_reply.dart`

- L6: /// Signal's swipe-to-reply: drag a message to the right, an arrow fades in and
- L9: /// Numbers are Signal's own (`ConversationSwipeAnimationHelper`): the gesture
- L111: /// 1.0 up to the trigger, then Signal's kick out to 1.8 and back.

## `lib/features/messages/chat-timeline/pending_preview_cache.dart`

- L9: /// could be shown. Signal draws the local file, and so do we now: the upload

## `lib/features/messages/chat-timeline/quote_chain.dart`

- L9: /// quoted — Signal's `hasBeenQuoted`, worked out from the loaded timeline
- L17: /// those, oldest first — Signal's `getMessagesInQuoteChain`. Empty when the
- L21: // Walk up to the root, as Signal's `getRootOfQuoteChain` does. The hop

## `lib/features/messages/chat-timeline/quote_replies_sheet.dart`

- L11: /// Signal's `MessageQuotesBottomSheet`: the message and everything that

## `lib/features/messages/chat-timeline/reaction_emoji_picker.dart`

- L4: /// Signal-style "react with any emoji" sheet.

## `lib/features/messages/chat-timeline/reaction_row.dart`

- L5: /// Signal's reaction pill: one capsule hanging off the bottom edge of the
- L10: /// on the long-press overlay ([MessageReactionBar]), same as Signal. Tapping an
- L58: // Signal shows a single total beside the emoji, not a count

## `lib/features/messages/chat-timeline/reaction_scrub.dart`

- L17: ///   picks one. Signal has no gaps here: the whole width is live.

## `lib/features/messages/chat-timeline/save_message_attachments.dart`

- L27: /// Signal's Save on a media message: every attachment it carries, one

## `lib/features/messages/chat-timeline/scroll_to_bottom_pill.dart`

- L3: /// Signal's jump-to-bottom button: a round chip above the composer that only

## `lib/features/messages/chat-timeline/sender_name_color.dart`

- L3: /// Signal gives every member of a group a stable name colour, so a run of
- L8: /// The palette follows Signal's own name-colour set in spirit: saturated

## `lib/features/messages/chat-timeline/timeline_jump_target.dart`

- L9: /// The wash is Signal's `pulseHighlight` — a message reached from somewhere

## `lib/features/messages/chat-timeline/unread_divider.dart`

- L3: /// Signal's "Unread messages" bar — a full-width rule with the count centred

## `lib/features/messages/chat-typing/typing_avatars.dart`

- L10: /// Faces of whoever is typing in a group, overlapped like Signal's group

## `lib/features/messages/chat_store_sync.dart`

- L40: /// process was frozen. Signal does the same pair on foreground — connect,

## `lib/features/messages/data/chat_details_api.dart`

- L5: /// The three reads and one write behind Signal's conversation-details screen:

## `lib/features/messages/data/local/chat_local_tables.dart`

- L77: /// [CachedMessages]. Signal decrypts once on receipt and stores the plaintext;

## `lib/features/messages/data/local/chat_message_row.dart`

- L15: /// under the same key (server id lives in the payload), matching Signal's

## `lib/features/messages/data/models/chat_conversation.dart`

- L201: /// Signal-style message request, from this viewer's side:

## `lib/features/messages/message_e2ee/message_vault_key_cache.dart`

- L8: /// message" over history sitting on the disk right beside it. Signal decrypts

## `lib/features/messages/message_e2ee/sidebar_preview.dart`

- L9: // Signal gets the same result by storing the decrypted snippet in its

## `lib/features/messages/message_e2ee/vault_gate_recovery_choice.dart`

- L9: /// How this phone gets the account's messages — Signal-Android's
- L13: /// starting fresh is the other card — confirmed first, like Signal's skip,

## `lib/features/messages/nickname/contact_nickname.dart`

- L7: /// *you* file someone under, on your own phone. Signal keeps the same pair, and

## `lib/features/messages/nickname/contact_nickname_store.dart`

- L11: /// for something nobody expects to follow them between devices. Signal keeps

## `lib/features/messages/nickname/nickname_sheet.dart`

- L7: /// Signal's "Nickname" editor: rename someone on this device.

## `lib/features/messages/note_to_self_avatar.dart`

- L11: /// accent colour says what the row is instead, the same way Signal does.

## `lib/features/messages/providers/chat_provider_older.dart`

- L13: /// again and written again while the reader watched a spinner. Signal's
- L15: /// with one thing Signal's protocol gives for free and ours does not: proof

## `lib/features/messages/providers/chat_provider_requests.dart`

- L3: /// Answering a Signal-style message request from inside the thread.

## `lib/features/messages/providers/chat_provider_resync.dart`

- L11: /// Signal reaches for the same two things when it wakes its connect loop: a

## `lib/features/messages/safety_number/member_key_watch.dart`

- L23: /// here, which is why it warns and does not block. Signal's rule.

## `lib/features/messages/safety_number/safety_number.dart`

- L14: /// The derivation is Signal's numeric fingerprint, kept exactly: 5200 rounds of

## `lib/features/messages/safety_number/safety_number_screen.dart`

- L7: /// Signal's "Verify safety number" screen.

## `lib/features/messages/screens/conversation_screen.dart`

- L150: // Back leaves multi-select before it leaves the conversation — Signal's

## `lib/features/messages/wallpaper/chat_wallpaper.dart`

- L35: /// Signal models this as a per-chat value that falls back to a global default,

## `lib/features/messages/wallpaper/chat_wallpaper_full_preview.dart`

- L10: /// Signal's flow: a tile is too small to judge a picture by, so choosing one

## `lib/features/messages/wallpaper/chat_wallpaper_presets.dart`

- L35: /// is how Signal's preset set is built.

## `lib/features/messages/wallpaper/chat_wallpaper_preview.dart`

- L8: /// Signal previews with two bubbles rather than a bare swatch, because the

## `lib/features/messages/wallpaper/chat_wallpaper_store.dart`

- L10: /// for something nobody expects to follow them between devices. Signal keeps

## `lib/features/notifications/chat/chat_notification_actions.dart`

- L74: // Replying already marks the conversation read. Match Signal's remote

## `lib/features/notifications/chat/chat_notification_ids.dart`

- L4: /// the messages inside a single entry the way Signal and the Google Messages

## `lib/features/notifications/local_notifications.dart`

- L43: // matching Signal's single requestAuthorization. Android ignores this.

## `lib/features/notifications/vitals/battery_prompt_decision.dart`

- L16: /// everyone, justified by nothing. Signal's rule is the opposite and is the one

## `lib/features/notifications/vitals/notification_vitals.dart`

- L26: /// Runs the vitals check — Signal's `VitalsViewModel`, minus the parts that
- L29: /// Called on every resume, so it is throttled the way Signal throttles it: at

## `lib/features/notifications/vitals/slow_notification_heuristics.dart`

- L5: /// The numbers are Signal's (`SlowNotificationHeuristics`), kept as they are
- L31: /// The index is `floor(n * p / 100) - 1`, which is Signal's
- L57: /// Signal reaches the same conclusion from three signals — failed FCM service

## `lib/features/notifications/widgets/battery_optimization_prompt.dart`

- L14: /// Signal's `PromptBatterySaverDialogFragment`: a sheet shown only after the

## `lib/features/notifications/widgets/notification_vitals_watcher.dart`

- L11: /// first frame after login, before the app had delivered a single push. Signal

## `lib/features/onboarding/permissions/permission_intro.dart`

- L10: /// Signal-Android's `GrantPermissionsFragment` decision: once per install,
- L46: /// has no row — Signal drops the notifications row below API 33 the same way.

## `lib/features/onboarding/permissions/permission_intro_gate.dart`

- L7: /// as Signal puts it in front of its restore screen. Shown once per install;

## `lib/features/onboarding/permissions/permission_intro_page.dart`

- L11: /// "Allow permissions" — Signal-Android's `GrantPermissionsScreen`: one row
- L14: /// Signal's pictures are its own colour illustrations (AGPL assets); these

## `lib/features/onboarding/profile-setup/profile_setup_gate.dart`

- L10: /// account — after the recovery screen, where Signal puts its own profile

## `lib/features/profile/screens/sessions_screen.dart`

- L17: /// Linked devices — Signal's screen of the same name.

## `lib/features/profile/widgets/session_tile.dart`

- L14: /// on every row. Signal puts them behind the overflow because the list is
- L151: /// neither, and Signal shows dates here for the same reason.

## `lib/features/realtime/socket_hold.dart`

- L5: /// background — Signal's keep-alive tokens, as one rule.

## `lib/features/realtime/ws_background_release.dart`

- L21: /// Signal's `maxBackgroundTime`: long enough for a quick app switch to come

## `lib/features/settings/account/account_screen.dart`

- L74: // Signal keeps "Transfer account" under Account: moving the

## `lib/features/settings/app-icon/app_icon_screen.dart`

- L9: /// Mirrors Signal's safe selection flow: preview first, then confirm before

## `lib/features/settings/avatar/avatar_flow.dart`

- L11: /// Signal's avatar flow: pick a photo, then move and scale it in a circular

## `lib/features/settings/data-storage/auto_download_dialog.dart`

- L6: /// Signal's multi-select: which connections this kind of media may download

## `lib/features/settings/data-storage/background_connection_row.dart`

- L11: /// Signal's "Stay connected in the background", as a status line rather than a

## `lib/features/settings/data-storage/data_storage_screen.dart`

- L21: /// Settings → Data and storage. Signal's screen of the same name.

## `lib/features/settings/data-storage/storage_review_screen.dart`

- L14: /// Signal's Review storage: everything on disk, biggest first, pick and delete.

## `lib/features/settings/data-storage/storage_review_tile.dart`

- L57: // Signal's selection circle, in the app's glyphs: no Material checkbox.

## `lib/features/settings/data-storage/storage_usage_bar.dart`

- L6: /// One stacked bar plus a legend — Signal's storage breakdown.

## `lib/features/settings/screens/edit_name_screen.dart`

- L13: /// Edit your own display name — Signal's "Profile name" screen.

## `lib/features/settings/screens/media_quality_screen.dart`

- L6: /// Settings → Media quality. Signal's "Sent media quality": how hard a picture

## `lib/features/settings/screens/my_qr_screen.dart`

- L19: /// Your own QR code — Signal's "QR code" screen, reached from the button

## `lib/features/settings/settings-hub/settings_row.dart`

- L7: /// Signal's `Rows.TextRow` shape — a flat full-bleed row rather than a card,

## `lib/features/settings/settings-hub/settings_section_header.dart`

- L3: /// Signal's small tinted heading above a group of rows.

## `lib/features/settings/settings-hub/settings_sections.dart`

- L14: /// The row groups under the bio block. Signal splits these with dividers

## `lib/features/settings/typing-indicators/typing_indicators_provider.dart`

- L9: /// The account's typing-indicator switch (Signal's rule: off means this

## `lib/features/settings/typing-indicators/typing_indicators_tile.dart`

- L8: /// Signal's switch: off means you neither show nor see "typing…".

## `lib/features/share_intake/screens/share_target_screen.dart`

- L22: /// Signal's flow, and for the same reason — the system share sheet has already

## `lib/features/share_intake/share-target/share_target_list.dart`

- L6: /// Conversation picker for an incoming share — Signal's "Share with" list.

## `lib/features/transfer-chats/ui/transfer_chats_screen.dart`

- L13: /// Settings → Account → Transfer chats: the OLD phone's side, Signal's

## `lib/main.dart`

- L194: // Signal's launch: the splash stays until auth knows chats or login.

## `lib/shared/avatar-store/avatar_index.dart`

- L32: /// URL) to the file holding its picture — Signal's `recipient.profile_avatar`

## `lib/shared/avatar-store/avatar_store.dart`

- L14: /// — Signal's `AvatarHelper` (one file per recipient) plus the
- L19: /// keeps being drawn while the new one downloads, then swaps in — Signal's

## `lib/shared/link-preview/link_preview_cache.dart`

- L19: /// v1 was the first on-device fetch (Signal-Android's approach). Before it,

## `lib/shared/link-preview/link_preview_data.dart`

- L3: /// One unfurled link, exactly the fields Signal-Android's `LinkPreview` carries
- L4: /// plus the image's real size — which Signal knows because the SENDER attached
- L36: /// Signal shows a card when it has EITHER a title or a picture

## `lib/shared/link-preview/link_preview_fetch.dart`

- L2: /// Signal-Android does it (`LinkPreviewRepository`), not through a proxy.
- L4: /// **The reader pays for it, and that is the accepted cost.** Signal unfurls in
- L21: /// Signal's `FAILSAFE_MAX_TEXT_SIZE`. Worth keeping exactly: YouTube serves an
- L26: /// Signal's `FAILSAFE_MAX_IMAGE_SIZE`.
- L29: /// OkHttp's own default, and the number Signal inherits.
- L32: /// Honest, and named after us. Signal sends `WhatsApp/2`; large sites do key
- L55: // Linked straight at a picture. Signal makes it the card and uses the file
- L111: // on a private address two jumps later — Signal guards the same seam

## `lib/shared/link-preview/link_preview_image_store.dart`

- L1: /// Downloads a preview picture onto this device — Signal-Android's
- L5: /// Signal never lets the renderer touch a remote address: the thumbnail is
- L13: /// What is NOT ported is Signal's re-encode: it recompresses to fit
- L28: /// Signal-Desktop's `VALID_IMAGE_MIME_TYPES`. Anything else claiming to be an
- L39: /// Signal-Desktop's `MIN_IMAGE_CONTENT_LENGTH`: below this there is no image,
- L95: /// once here rather than in `build`: Signal gets them free because the SENDER

## `lib/shared/link-preview/link_preview_loader.dart`

- L44: // image widget to fetch — Signal's `fetchThumbnail`, and the only way the

## `lib/shared/link-preview/link_preview_parse.dart`

- L1: /// Signal-Android's `LinkPreviewUtil.parseOpenGraphFields`, with one shape
- L2: /// change: Signal writes a separate pattern per property family and only ever
- L28: /// it — Signal leaves a relative favicon href as it found it, which simply
- L64: // Signal falls back to the favicon when there is no og:image, and so do we:
- L87: // Signal decodes twice: plenty of pages emit `&amp;quot;` in a meta tag.

## `lib/shared/link-preview/link_safety.dart`

- L1: /// Signal-Android's `util/LinkUtil.kt`, ported. A link is only fetched — and
- L83: /// caught here — that is Signal's own boundary, and closing it needs the
- L113: /// The domain shown on the card. Signal draws `topPrivateDomain()`; without a

## `lib/shared/media/crop_transform.dart`

- L34: /// The scale at which the image exactly covers the window — Signal's avatar

## `lib/shared/media/device_gallery.dart`

- L51: /// Signal's wallpaper picker opens onto this list rather than a flat "Recent"
- L91: /// Reads the device library directly, the way Signal's attachment keyboard

## `lib/shared/media/media_folder_gallery.dart`

- L20: /// Signal-style album gallery: folders first, then photos in the chosen album.

## `lib/shared/media/media_grid_sheet.dart`

- L16: /// Signal's attachment keyboard: the library itself, in the sheet, rather than

## `lib/shared/media/media_grid_tile.dart`

- L9: /// number is also the send order — the thing Signal's grid tells you that a

## `lib/shared/media/media_quality.dart`

- L6: /// Signal's two levels. The codes match `MediaQuality` on the Android side —

## `lib/shared/media/media_thumbnail.dart`

- L11: /// which is the trade Signal makes for a grid that never flickers.

## `lib/shared/media/native_media_send.dart`

- L72: /// Signal's picker, review screen and editor, drawn in Kotlin.

## `lib/shared/media/pick_wallpaper_photo.dart`

- L6: /// Wallpaper photo: Signal folder gallery on Android, not the Recent sheet.

## `lib/shared/media/save_to_phone_action.dart`

- L9: /// Signal's shape — confirmation dialog, then a single result message for the

## `lib/shared/media/save_to_phone_dialog.dart`

- L16: /// Signal's save confirmation, one for one.

## `lib/shared/onboarding/onboarding_option_card.dart`

- L5: /// One choice on a first-run screen — Signal-Android's restore

## `lib/shared/onboarding/onboarding_page.dart`

- L3: /// The frame every first-run screen is drawn in — Signal-Android's
- L27: /// Signal's `horizontalGutters()`.

## `lib/shared/widgets/app_avatar.dart`

- L59: // Drawn from the phone's own copy (Signal's AvatarHelper, WhatsApp's

## `lib/shared/widgets/image_preview.dart`

- L12: /// Fullscreen pinch-zoom gallery — Signal-Android chrome, same as chat.

## `lib/shared/widgets/image_preview_chrome.dart`

- L3: /// Signal-Android's media-preview chrome (`fragment_media_preview`).
- L5: /// Forced dark — the viewer owns the screen the way Signal's activity does.

## `lib/shared/widgets/image_preview_zoom.dart`

- L29: /// Single tap — Signal toggles the chrome. Double-tap still zooms.

## `lib/shared/widgets/media_preview_actions.dart`

- L10: /// Signal's media-viewer actions, in Signal's two places.

## `lib/shared/widgets/video_fullscreen_controls.dart`

- L10: /// Scrub pauses, then resumes if it was playing — Signal's TimeBar rule.

## `lib/shared/widgets/video_thumb_states.dart`

- L48: /// Signal's play / pause affordance: a light disc over the frame.
- L82: /// Running time, bottom-left of a video tile. Signal shows it before you open
- L122: /// Signal's remaining label: `–1:23`. Never negative.

## `test/features/attachments/attachment_no_gallery_export_test.dart`

- L23: /// MediaStore rows survived. Signal's rule instead: nothing leaves the sandbox

## `test/features/calls/background_voice_call_gate_test.dart`

- L32: 'never rings while this phone is in a call (Signal busy rule)',

## `test/features/calls/call_audio_output_test.dart`

- L19: group('Signal picker rule (SHOW_PICKER_THRESHOLD = 3)', () {

## `test/features/calls/call_log_cluster_test.dart`

- L83: // The whole point of Signal's isEventMatch: a missed call is what

## `test/features/calls/incoming_call_view_test.dart`

- L68: testWidgets('Decline and Answer sit where Signal puts them', (tester) async {
- L125: // Two labelled seats 45dp apart (Signal's LandscapeButtons).

## `test/features/calls/live_call_test.dart`

- L8: /// Signal's busy rule: only an idle phone rings. These are the phases that

## `test/features/calls/video_fit_test.dart`

- L26: // fraction, which is what Signal draws.

## `test/features/messages/chat_message_cluster_test.dart`

- L181: // Signal hangs the avatar off the *bottom* of a run — the opposite of the

## `test/features/messages/message_menu_geometry_test.dart`

- L48: // Signal moves the message rather than flipping the menu: the bubble rises

## `test/features/messages/message_multiselect_test.dart`

- L185: // Signal's gutter: an incoming row moves from 16 to 48. An outgoing one
- L251: // Two messages: Signal drops everything that only means anything against

## `test/features/messages/message_selection_test.dart`

- L90: test('two messages drop reply, edit and save — Signal\'s rule', () {
- L154: test('forwarding stops at Signal\'s 32-message cap', () {

## `test/features/messages/new_chat_setup_test.dart`

- L87: // Like Signal's skip, starting fresh is confirmed first.

## `test/features/messages/reaction_scrub_test.dart`

- L8: // A 320-wide bar with Signal's seven slots: six emoji and "more".

## `test/shared/link_preview/link_preview_parse_test.dart`

- L29: // Signal folds the favicon into the image slot, and a small square is
- L34: test('takes single-quoted markup, which Signal drops on the floor', () {
- L50: test('decodes entities twice, as Signal does', () {

## `test/shared/link_preview/link_safety_test.dart`

- L55: // A routable literal is still allowed — Signal only blocks private ones.
