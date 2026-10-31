import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../decline-message/decline_message_panel.dart';
import '../widgets/call_network_badge.dart';
import '../widgets/call_backdrop.dart';
import '../widgets/incoming_call_buttons.dart';
import '../widgets/incoming_call_header.dart';

/// The ringing screen — the reference app's `IncomingCallScreen`, and the ONLY
/// one.
///
/// The reference app has one call Activity; its ringing notification opens it,
/// and it draws this layout until the call is answered. Ours is the same: the
/// CallKit notification's full-screen intent opens `/call`, which shows this
/// (`android/patches/callkit-ring-surface.gradle`); the plugin's own native
/// ringing Activity is never started for a DM call.
///
/// Layout, the reference app's numbers: the caller's photo blurred edge to edge
/// under a 40% black scrim; kind label, 80dp avatar, name, status; then at the
/// bottom Decline left and Answer right, 78dp each, 64dp in from the sides and
/// 24dp up. Landscape puts the buttons in one row, 45dp apart.
///
/// Message (decline with a text) and Silence are ours, not the reference app's.
/// They sit where the reference app puts its one secondary action ("Answer
/// without video"): a 56dp circle in a 78dp seat above the pair, so the pair
/// stays the target.
class IncomingCallView extends StatefulWidget {
  const IncomingCallView({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    required this.onDecline,
    required this.onAccept,
    this.onDeclineWithMessage,
    this.onSilence,
    this.video = false,
    this.lang = 'en',
  });

  final String peerName;
  final String? peerAvatar;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  /// Null hides Message (no conversation to write into).
  final ValueChanged<String>? onDeclineWithMessage;
  final Future<void> Function()? onSilence;
  final bool video;
  final String lang;

  @override
  State<IncomingCallView> createState() => _IncomingCallViewState();
}

class _IncomingCallViewState extends State<IncomingCallView> {
  bool _replyOpen = false;
  bool _silenced = false;

  String _tr(String key) => AppTranslations.of(widget.lang, key);

  void _silence() {
    if (_silenced) return;
    setState(() => _silenced = true);
    widget.onSilence?.call();
  }

  void _openReplies() {
    // Choosing words takes a moment; the tone should not shout through it.
    if (widget.onSilence != null) _silence();
    setState(() => _replyOpen = true);
  }

  void _closeReplies() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _replyOpen = false);
  }

  List<Widget> _secondary() => [
    if (widget.onDeclineWithMessage != null)
      IncomingCallButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: _tr('call_control_message'),
        secondary: true,
        onPressed: _openReplies,
      ),
    if (widget.onSilence != null)
      IncomingCallButton(
        icon: _silenced
            ? Icons.notifications_off_rounded
            : Icons.notifications_off_outlined,
        label: _tr('call_control_silence'),
        secondary: true,
        selected: _silenced,
        onPressed: _silenced ? null : _silence,
      ),
  ];

  Widget get _decline => IncomingCallButton(
    icon: Icons.call_end_rounded,
    label: _tr('call_control_decline'),
    color: declineColor,
    onPressed: widget.onDecline,
  );

  Widget get _answer => IncomingCallButton(
    icon: widget.video ? Icons.videocam_rounded : Icons.call_rounded,
    label: _tr('call_control_answer'),
    color: answerColor,
    onPressed: widget.onAccept,
  );

  Widget _portraitButtons() {
    final secondary = _secondary();
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 0, 64, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secondary.isNotEmpty) ...[
            Row(
              mainAxisAlignment: secondary.length == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: secondary,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_decline, const Spacer(), _answer],
          ),
        ],
      ),
    );
  }

  Widget _landscapeButtons() => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 45,
      children: [_decline, ..._secondary(), _answer],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final status = _tr(
      _silenced ? 'call_status_silenced' : 'call_status_incoming',
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        CallBackdrop(avatarUrl: widget.peerAvatar, blurSigma: 25),
        SafeArea(
          child: Column(
            children: [
              // The reference app: the header hangs from the top, a weighted
              // spacer pushes the buttons to the bottom.
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    child: IncomingCallHeader(
                      kindLabel: _tr(
                        widget.video
                            ? 'call_incoming_label_video'
                            : 'call_incoming_label_voice',
                      ),
                      video: widget.video,
                      name: widget.peerName,
                      avatarUrl: widget.peerAvatar,
                      status: status,
                      landscape: landscape,
                    ),
                  ),
                ),
              ),
              if (landscape) _landscapeButtons() else _portraitButtons(),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 14,
          right: 16,
          child: CallNetworkBadge(lang: widget.lang, ownLink: true),
        ),
        if (_replyOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeReplies,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DeclineMessagePanel(
              lang: widget.lang,
              onClose: _closeReplies,
              onPick: (text) {
                FocusManager.instance.primaryFocus?.unfocus();
                widget.onDeclineWithMessage?.call(text);
              },
            ),
          ),
        ],
      ],
    );
  }
}
