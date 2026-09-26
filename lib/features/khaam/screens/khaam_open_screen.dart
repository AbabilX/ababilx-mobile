import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/display_name.dart';
import '../../messages/chat_icon.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/khaam_covers.dart';
import '../data/khaam_payload.dart';
import '../providers/khaam_open_provider.dart';
import '../widgets/khaam_card.dart';
import '../widgets/khaam_card_entrance.dart';
import '../widgets/khaam_confetti.dart';
import '../widgets/khaam_cover_art.dart';
import '../widgets/khaam_caption.dart';
import '../widgets/khaam_open_footer.dart';
import '../widgets/khaam_photo.dart';
import '../widgets/khaam_scratch_foil.dart';

/// A Khaam, full screen: the card rises into place, the message waits under
/// foil for the receiver's finger, and scratching enough of it (or Reveal
/// all) lifts the rest, pops the message and throws confetti. The sender, or
/// the receiver on a later visit, gets the card with no foil at all.
class KhaamOpenScreen extends ConsumerStatefulWidget {
  const KhaamOpenScreen({
    super.key,
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  final ChatMessage message;
  final KhaamPayload payload;
  final bool isOwn;

  @override
  ConsumerState<KhaamOpenScreen> createState() => _KhaamOpenScreenState();
}

class _KhaamOpenScreenState extends ConsumerState<KhaamOpenScreen>
    with SingleTickerProviderStateMixin {
  /// The card's entrance, run once the opened state is known.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  KhaamOpenArgs get _args => KhaamOpenArgs(
    message: widget.message,
    payload: widget.payload,
    isOwn: widget.isOwn,
  );

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _reveal() {
    if (ref.read(khaamOpenProvider(_args)).phase != KhaamOpenPhase.sealed) {
      return;
    }
    unawaited(ref.read(khaamOpenProvider(_args).notifier).open());
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final open = ref.watch(khaamOpenProvider(_args));
    final phase = open.phase;
    final sealed = phase == KhaamOpenPhase.sealed;
    final cover = khaamCoverById(widget.payload.coverId);
    final senderName = widget.isOwn
        ? t('khaam_you')
        : safeDisplayName(widget.message.userName, fallback: 'Ababil X');
    final width = math.min(MediaQuery.sizeOf(context).width - 48, 340.0);
    if (phase != KhaamOpenPhase.loading && _enter.isDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _enter.isDismissed) unawaited(_enter.forward());
      });
    }
    ref.listen(khaamOpenProvider(_args).select((s) => s.celebrate), (_, now) {
      if (now) HapticFeedback.heavyImpact();
    });

    final text = widget.payload.message.trim();
    final photo = khaamPhotoOf(widget.message, widget.payload);
    final box = khaamPhotoBox(khaamEnvelopeWidth(context, width));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: sealed ? null : () => Navigator.of(context).pop(),
            ),
          ),
          if (phase != KhaamOpenPhase.loading)
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 48),
                // A scratch must never turn into a scroll.
                physics: sealed
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: KhaamCardEntrance(
                  animation: _enter,
                  child: KhaamCard(
                    cover: cover,
                    width: width,
                    fromLabel: t('khaam_from').replaceAll('{name}', senderName),
                    // The memory takes the cover's place once the foil lifts.
                    photo: photo == null || sealed
                        ? null
                        : KhaamPhoto(
                            attachment: photo,
                            width: box.width,
                            height: box.height,
                            radius: 0,
                          ),
                    senderName: senderName,
                    senderAvatar: widget.isOwn
                        ? null
                        : widget.message.userAvatarUrl,
                    caption: KhaamScratchFoil(
                      cover: cover,
                      hint: t('khaam_scratch_hint'),
                      cleared: !sealed,
                      onScratchedEnough: _reveal,
                      radius: 10,
                      child: KhaamCaption(
                        cover: cover,
                        text: text,
                        sealed: sealed,
                      ),
                    ),
                    footer: KhaamOpenFooter(
                      cover: cover,
                      sealed: sealed,
                      helpLabel: t('khaam_scratch_help'),
                      revealLabel: t('khaam_reveal_all'),
                      doneLabel: t('khaam_done'),
                      onReveal: _reveal,
                      onDone: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
          if (open.celebrate)
            Positioned.fill(
              child: IgnorePointer(
                child: KhaamConfetti(
                  colors: [
                    cover.accent,
                    cover.flap,
                    cover.top,
                    Colors.white,
                    const Color(0xFFFFD166),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const ChatIcon(
                  HugeIcons.strokeRoundedCancel01,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
