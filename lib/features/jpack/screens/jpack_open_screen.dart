import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/display_name.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_payload.dart';
import '../providers/jpack_open_provider.dart';
import '../widgets/jpack_confetti.dart';
import '../widgets/jpack_cover_art.dart';
import '../widgets/jpack_details_card.dart';
import '../widgets/jpack_envelope.dart';

class JPackOpenScreen extends ConsumerStatefulWidget {
  const JPackOpenScreen({
    super.key,
    required this.message,
    required this.payload,
    required this.isOwn,
  });

  final ChatMessage message;
  final JPackPayload payload;
  final bool isOwn;

  @override
  ConsumerState<JPackOpenScreen> createState() => _JPackOpenScreenState();
}

class _JPackOpenScreenState extends ConsumerState<JPackOpenScreen>
    with TickerProviderStateMixin {
  /// 0 sealed → 1 flaps gone. A drag writes it directly; a release or a tap
  /// on the seal animates the rest of the way.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  /// The seal's coin-flip while it opens.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  JPackOpenArgs get _args => JPackOpenArgs(
    message: widget.message,
    payload: widget.payload,
    isOwn: widget.isOwn,
  );

  JPackOpenPhase get _phase => ref.read(jpackOpenProvider(_args)).phase;

  @override
  void initState() {
    super.initState();
    _open.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(ref.read(jpackOpenProvider(_args).notifier).open());
      }
    });
  }

  @override
  void dispose() {
    _open.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_phase != JPackOpenPhase.sealed || _open.isAnimating) return;
    final height = jpackEnvelopeWidth(context) / jpackCoverAspect;
    _open.value = (_open.value - d.primaryDelta! / (height * 0.55)).clamp(
      0.0,
      1.0,
    );
  }

  void _onDragEnd(DragEndDetails d) {
    if (_phase != JPackOpenPhase.sealed) return;
    final flung = (d.primaryVelocity ?? 0) < -700;
    if (flung || _open.value > 0.4) {
      _startOpen();
    } else {
      unawaited(_open.animateBack(0, curve: Curves.easeOutCubic));
    }
  }

  void _startOpen() {
    if (_phase != JPackOpenPhase.sealed ||
        _open.status == AnimationStatus.forward) {
      return;
    }
    HapticFeedback.mediumImpact();
    unawaited(_spin.forward(from: 0));
    unawaited(_open.forward());
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final open = ref.watch(jpackOpenProvider(_args));
    final phase = open.phase;
    final cover = jpackCoverById(widget.payload.coverId);
    final senderName = widget.isOwn
        ? t('jpack_you')
        : safeDisplayName(widget.message.userName, fallback: 'Ababil X');
    final senderAvatar = widget.isOwn ? null : widget.message.userAvatarUrl;
    ref.listen(jpackOpenProvider(_args).select((s) => s.celebrate), (_, now) {
      if (now) HapticFeedback.heavyImpact();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: phase == JPackOpenPhase.sealed
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.18),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: switch (phase) {
                JPackOpenPhase.loading => const SizedBox.shrink(),
                JPackOpenPhase.sealed => JPackEnvelope(
                  key: const ValueKey('sealed'),
                  width: jpackEnvelopeWidth(context),
                  cover: cover,
                  payload: widget.payload,
                  senderName: senderName,
                  senderAvatar: senderAvatar,
                  fromLabel: t('jpack_from').replaceAll('{name}', senderName),
                  openLabel: t('jpack_open'),
                  swipeLabel: t('jpack_swipe_up'),
                  open: _open,
                  spin: _spin,
                  onSealTap: _startOpen,
                  onDragUpdate: _onDragUpdate,
                  onDragEnd: _onDragEnd,
                ),
                JPackOpenPhase.revealed => JPackDetailsCard(
                  key: const ValueKey('revealed'),
                  payload: widget.payload,
                  cover: cover,
                  senderName: senderName,
                  senderAvatar: senderAvatar,
                  width: math.min(MediaQuery.sizeOf(context).width - 48, 340.0),
                ),
              },
            ),
          ),
          if (open.celebrate)
            Positioned.fill(
              child: JPackConfetti(
                colors: [
                  cover.accent,
                  cover.flap,
                  cover.top,
                  Colors.white,
                  const Color(0xFFFFD166),
                ],
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
