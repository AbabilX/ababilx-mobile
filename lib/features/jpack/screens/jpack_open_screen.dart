import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/display_name.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../messages/data/models/chat_models.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_money.dart';
import '../data/jpack_payload.dart';
import '../data/jpack_status.dart';
import '../providers/jpack_open_provider.dart';
import '../providers/jpack_providers.dart';
import '../widgets/ababil_pay_sheet.dart';
import '../widgets/jpack_confetti.dart';
import '../widgets/jpack_cover_art.dart';

/// Opens a JPack from its bubble. The receiver swipes it open; anybody else —
/// the sender, or the receiver a second time — goes straight to the details.
Future<void> openJPack(
  BuildContext context, {
  required ChatMessage message,
  required JPackPayload payload,
  required bool isOwn,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          JPackOpenScreen(message: message, payload: payload, isOwn: isOwn),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    ),
  );
}

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

  JPackCover get _cover => jpackCoverById(widget.payload.coverId);

  JPackOpenArgs get _args => JPackOpenArgs(
    message: widget.message,
    payload: widget.payload,
    isOwn: widget.isOwn,
  );

  JPackOpenPhase get _phase => ref.read(jpackOpenProvider(_args)).phase;

  /// Height of the envelope as last laid out; the drag is measured against it.
  double _envelopeHeight(BuildContext context) =>
      _envelopeWidth(context) / jpackCoverAspect;

  static double _envelopeWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.78, 320.0);

  @override
  void initState() {
    super.initState();
    _open.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(ref.read(jpackOpenProvider(_args).notifier).claim());
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
    _open.value =
        (_open.value - d.primaryDelta! / (_envelopeHeight(context) * 0.55))
            .clamp(0.0, 1.0);
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

  String get _senderName => widget.isOwn
      ? AppTranslations.translate(context, ref, 'jpack_you')
      : safeDisplayName(widget.message.userName, fallback: 'Ababil X');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = _envelopeWidth(context);
    final open = ref.watch(jpackOpenProvider(_args));
    final phase = open.phase;
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
                JPackOpenPhase.sealed => KeyedSubtree(
                  key: const ValueKey('sealed'),
                  child: _envelope(width),
                ),
                JPackOpenPhase.expired => KeyedSubtree(
                  key: const ValueKey('expired'),
                  child: _JPackExpired(
                    message: widget.message,
                    payload: widget.payload,
                    cover: _cover,
                    senderName: _senderName,
                    senderAvatar: widget.isOwn
                        ? null
                        : widget.message.userAvatarUrl,
                    isOwn: widget.isOwn,
                    width: math.min(size.width - 48, 340.0),
                  ),
                ),
                JPackOpenPhase.revealed => KeyedSubtree(
                  key: const ValueKey('revealed'),
                  child: _JPackDetails(
                    payload: widget.payload,
                    cover: _cover,
                    senderName: _senderName,
                    senderAvatar: widget.isOwn
                        ? null
                        : widget.message.userAvatarUrl,
                    isOwn: widget.isOwn,
                    animateAmount: open.celebrate,
                    width: math.min(size.width - 48, 340.0),
                  ),
                ),
              },
            ),
          ),
          if (open.celebrate)
            Positioned.fill(
              child: JPackConfetti(
                colors: [
                  _cover.accent,
                  _cover.flap,
                  _cover.top,
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

  Widget _envelope(double width) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final cover = _cover;
    final height = width / jpackCoverAspect;
    final seal = jpackSealCenter(Size(width, height));
    final sealR = jpackSealRadius(Size(width, height));

    final heading = Padding(
      padding: EdgeInsets.fromLTRB(20, height * 0.08, 20, 0),
      child: Column(
        children: [
          AppAvatar(
            size: 48,
            url: widget.message.userAvatarUrl,
            name: _senderName,
          ),
          const SizedBox(height: 10),
          Text(
            t('jpack_from').replaceAll('{name}', _senderName),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cover.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black26)],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.payload.message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cover.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black26)],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: height,
            child: AnimatedBuilder(
              animation: Listenable.merge([_open, _spin]),
              builder: (context, _) {
                final p = Curves.easeIn.transform(_open.value);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The flap drops away first…
                    Transform.translate(
                      offset: Offset(0, p * height * 0.6),
                      child: Opacity(
                        opacity: (1 - p * 1.4).clamp(0.0, 1.0),
                        child: ClipPath(
                          clipper: _PathClipper(jpackLowerPath),
                          child: JPackCoverArt(
                            cover: cover,
                            width: width,
                            part: JPackCoverPart.lower,
                            showSeal: false,
                          ),
                        ),
                      ),
                    ),
                    // …while the upper panel lifts off, tipping back in 3D.
                    Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..translateByDouble(0.0, -p * height * 0.7, 0.0, 1.0)
                        ..rotateX(p * 1.1),
                      child: Opacity(
                        opacity: (1 - p * 1.2).clamp(0.0, 1.0),
                        child: ClipPath(
                          clipper: _PathClipper(jpackUpperPath),
                          child: JPackCoverArt(
                            cover: cover,
                            width: width,
                            part: JPackCoverPart.upper,
                            showSeal: false,
                            child: heading,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: seal.dx - sealR * 1.15,
                      top: seal.dy - sealR * 1.15 + p * height * 0.2,
                      width: sealR * 2.3,
                      height: sealR * 2.3,
                      child: Opacity(
                        opacity: (1 - p * 1.6).clamp(0.0, 1.0),
                        child: GestureDetector(
                          onTap: _startOpen,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(_spin.value * math.pi * 4),
                            child: _PulsingSeal(
                              child: JPackSeal(
                                cover: cover,
                                label: t('jpack_open'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: _open,
            builder: (_, child) => Opacity(
              opacity: (1 - _open.value * 2).clamp(0.0, 1.0),
              child: child,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  color: Colors.white70,
                ),
                const SizedBox(height: 4),
                Text(
                  t('jpack_swipe_up'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.build);

  final Path Function(Size) build;

  @override
  Path getClip(Size size) => build(size);

  @override
  bool shouldReclip(_PathClipper old) => false;
}

/// A slow breath on the seal so it reads as the thing to press.
class _PulsingSeal extends StatefulWidget {
  const _PulsingSeal({required this.child});

  final Widget child;

  @override
  State<_PulsingSeal> createState() => _PulsingSealState();
}

class _PulsingSealState extends State<_PulsingSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// What is inside: who sent it, what it says, how much, and where it went.
class _JPackDetails extends ConsumerWidget {
  const _JPackDetails({
    required this.payload,
    required this.cover,
    required this.senderName,
    required this.senderAvatar,
    required this.isOwn,
    required this.animateAmount,
    required this.width,
  });

  final JPackPayload payload;
  final JPackCover cover;
  final String senderName;
  final String? senderAvatar;
  final bool isOwn;
  final bool animateAmount;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final balance = ref.watch(walletBalanceProvider).valueOrNull;

    return GestureDetector(
      onTap: () {}, // taps on the card must not close the screen
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 116,
                width: width,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [cover.top, cover.flap],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(painter: _ArcPainter(colors.surface)),
                    ),
                    Align(
                      alignment: const Alignment(0, 1.1),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: AppAvatar(
                          size: 56,
                          url: senderAvatar,
                          name: senderName,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  children: [
                    Text(
                      t('jpack_from').replaceAll('{name}', senderName),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payload.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: animateAmount ? 0 : payload.amount,
                        end: payload.amount,
                      ),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, _) => Text(
                        formatTaka(value, fixed: true),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cover.flap,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AbabilPayMark(size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isOwn
                                  ? t('jpack_sender_note')
                                  : t('jpack_credited'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isOwn && balance != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        t('jpack_new_balance').replaceAll(
                          '{amount}',
                          formatTaka(balance, fixed: true),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cover.flap,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(t('jpack_done')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The curved lower edge of the details header — the same smile as the flap.
class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(
        size.width / 2,
        size.height * 1.05,
        size.width,
        size.height * 0.62,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

/// The claim window is over. Receiver: it can no longer be opened. Sender:
/// the window closed — this phone cannot know whether it was opened in time.
class _JPackExpired extends ConsumerWidget {
  const _JPackExpired({
    required this.message,
    required this.payload,
    required this.cover,
    required this.senderName,
    required this.senderAvatar,
    required this.isOwn,
    required this.width,
  });

  final ChatMessage message;
  final JPackPayload payload;
  final JPackCover cover;
  final String senderName;
  final String? senderAvatar;
  final bool isOwn;
  final double width;

  /// A cover with its colour drained: still recognisably this JPack, plainly
  /// no longer live.
  static const _desaturate = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // The app registers no date symbols for Bangla, so the date stays in the
    // English month format the rest of the chat already uses.
    final format = DateFormat('d MMM yyyy, h:mm a');
    String when(DateTime? at) => at == null ? '—' : format.format(at.toLocal());
    const artWidth = 96.0;
    const visible = 0.62;

    return GestureDetector(
      onTap: () {}, // taps on the card must not close the screen
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: artWidth,
                  height: artWidth / jpackCoverAspect * visible,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: 0.55,
                        child: ColorFiltered(
                          colorFilter: _desaturate,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: visible,
                              child: JPackCoverArt(
                                cover: cover,
                                width: artWidth,
                                showSeal: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -14,
                        bottom: -14,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: colors.errorContainer,
                            child: Icon(
                              Icons.hourglass_disabled_rounded,
                              size: 20,
                              color: colors.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  t(isOwn ? 'jpack_claim_closed_title' : 'jpack_expired_title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(isOwn ? 'jpack_claim_closed_body' : 'jpack_expired_body'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AppAvatar(
                            size: 32,
                            url: senderAvatar,
                            name: senderName,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(
                                    'jpack_from',
                                  ).replaceAll('{name}', senderName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge,
                                ),
                                if (payload.message.trim().isNotEmpty)
                                  Text(
                                    payload.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatTaka(payload.amount, fixed: true),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurfaceVariant,
                              decoration: isOwn
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      _MetaLine(
                        icon: Icons.send_rounded,
                        text: t(
                          'jpack_sent_at',
                        ).replaceAll('{date}', when(jpackSentAt(message))),
                      ),
                      const SizedBox(height: 6),
                      _MetaLine(
                        icon: Icons.event_busy_rounded,
                        text: t(
                          'jpack_expired_at',
                        ).replaceAll('{date}', when(jpackExpiresAt(message))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t('jpack_done')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
