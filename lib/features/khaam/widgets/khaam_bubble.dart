import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-select/message_selection.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/khaam_covers.dart';
import '../data/khaam_payload.dart';
import '../data/khaam_status.dart';
import '../providers/khaam_providers.dart';
import '../screens/khaam_open_route.dart';
import 'khaam_cover_art.dart';
import 'khaam_caption.dart';
import 'khaam_envelope_face.dart';
import 'khaam_foil_painter.dart';
import 'khaam_photo.dart';

/// A Khaam in the timeline. Fills the bubble edge to edge, like media; the
/// bubble's own footer (time, ticks) sits under it.
///
/// The receiver sees the cover and a strip of foil until they scratch the
/// card open — the message is never printed here before that. No label and
/// no status row: the cover and the foil already say what this is.
class KhaamBubbleCard extends ConsumerWidget {
  const KhaamBubbleCard({
    super.key,
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  static const width = 200.0;
  static const _envelope = width;
  static final _photo = khaamPhotoBox(_envelope);

  final ChatMessage message;
  final KhaamPayload payload;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final cover = khaamCoverById(payload.coverId);
    final opened = khaamIsOpened(
      ref.watch(khaamOpenedIdsProvider).valueOrNull,
      payload.id,
    );
    final selecting = ref.watch(messageSelectionProvider).isActive;
    final failed = message.sendStatus == MessageSendStatus.failed;
    final state = khaamStatus(isOwn: isOwn, opened: opened);
    final text = payload.message.trim();
    final photo = khaamPhotoOf(message, payload);

    final status = switch (state) {
      KhaamStatus.sent => t('khaam_sent'),
      KhaamStatus.opened => t('khaam_opened'),
      KhaamStatus.unopened => t('khaam_tap_to_open'),
    };

    // The portrait envelope and nothing else: foil on the flap until opened,
    // then the message there and the memory photo in the upper panel.
    final card = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KhaamEnvelopeFace(
            cover: cover,
            width: _envelope,
            photo: photo == null || state == KhaamStatus.unopened
                ? null
                : KhaamPhoto(
                    attachment: photo,
                    width: _photo.width,
                    height: _photo.height,
                    radius: 0,
                    open: false,
                  ),
            caption: state == KhaamStatus.unopened
                ? KhaamFoilStrip(cover: cover, hint: t('khaam_scratch_hint'))
                : KhaamCaption(cover: cover, text: text),
          ),
        ],
      ),
    );

    // While picking rows, or when the send failed, the row's own tap wins:
    // selecting toggles, a failed bubble retries.
    if (selecting || failed || message.isPending) return card;
    return Semantics(
      button: true,
      label: '${payload.fallbackText}. $status',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openKhaam(
          context,
          message: message,
          payload: payload,
          isOwn: isOwn,
        ),
        child: card,
      ),
    );
  }
}
