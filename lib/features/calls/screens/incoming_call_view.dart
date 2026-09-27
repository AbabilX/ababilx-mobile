import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../decline-message/decline_message_panel.dart';
import '../widgets/call_overlay_metrics.dart';
import '../widgets/call_peer_identity.dart';
import '../widgets/call_wallpaper.dart';
import '../widgets/incoming_call_pair.dart';
import '../widgets/incoming_call_secondary.dart';

/// Ringing incoming call — same wallpaper + identity language as outgoing.
///
/// Top to bottom: what is ringing (voice / video), the caller, then Message
/// and Silence in a small row, then the large Decline / Answer pair. Laid out
/// as a column with flexible space rather than fixed fractions, so the extra
/// row can never slide under the caller's face on a short screen.
///
/// Message opens [DeclineMessagePanel] inside this screen; picking a reply
/// declines the call and sends the text into the DM.
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

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    final padding = MediaQuery.paddingOf(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final sideInset = math.max(math.max(padding.left, padding.right), 12.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        const CallWallpaper(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            sideInset,
            padding.top + 16,
            sideInset,
            m.incomingActionsBottom(padding.bottom),
          ),
          child: Column(
            children: [
              IncomingCallKindLabel(
                video: widget.video,
                text: _tr(
                  widget.video
                      ? 'call_incoming_label_video'
                      : 'call_incoming_label_voice',
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: m.size.width - sideInset * 2,
                      child: CallPeerIdentity(
                        name: widget.peerName,
                        avatarUrl: widget.peerAvatar,
                        status: _tr(
                          _silenced
                              ? 'call_status_silenced'
                              : 'call_status_incoming',
                        ),
                        showWave: !landscape && !_silenced,
                      ),
                    ),
                  ),
                ),
              ),
              IncomingCallSecondary(
                messageLabel: _tr('call_control_message'),
                silenceLabel: _tr('call_control_silence'),
                silenced: _silenced,
                showLabels: !landscape,
                onMessage: widget.onDeclineWithMessage == null
                    ? null
                    : _openReplies,
                onSilence: widget.onSilence == null ? null : _silence,
              ),
              SizedBox(height: m.design(56).clamp(20.0, 36.0)),
              IncomingCallPair(
                video: widget.video,
                declineLabel: _tr('call_control_decline'),
                answerLabel: _tr('call_control_answer'),
                showLabels: !landscape,
                onDecline: widget.onDecline,
                onAccept: widget.onAccept,
              ),
            ],
          ),
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
