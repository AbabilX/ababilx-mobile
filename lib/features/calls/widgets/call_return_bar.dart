import 'dart:async';

import 'package:flutter/material.dart';

/// The strip across the top of the app while a call is running somewhere else.
///
/// WhatsApp and Signal both keep the call *legible* from outside it: the bar
/// carries who you are talking to and how long it has been going, not just an
/// invitation to come back. A frozen "Tap to return to call" cannot say whether
/// the call is still up, still ringing, or has been reconnecting for a minute —
/// which is exactly what someone who left the screen wants to know.
///
/// [status] is a callback rather than a string because the bar ticks its own
/// clock: the parent rebuilds when call *state* changes, and a running duration
/// is not a state change.
class CallReturnBar extends StatefulWidget {
  const CallReturnBar({
    super.key,
    required this.title,
    required this.status,
    required this.onTap,
    this.ticking = false,
    this.alerting = false,
    this.returnLabel,
  });

  final String title;
  final String? returnLabel;

  /// Read once per second while [ticking], and on every rebuild otherwise.
  final String Function() status;

  final VoidCallback onTap;

  /// The status changes on its own (a running call's duration).
  final bool ticking;

  /// Something is wrong — a recovery in progress. Tints the bar so a glance is
  /// enough, the way Signal reddens its own bar.
  final bool alerting;

  @override
  State<CallReturnBar> createState() => _CallReturnBarState();
}

class _CallReturnBarState extends State<CallReturnBar> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(CallReturnBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _syncClock() {
    if (!widget.ticking) {
      _clock?.cancel();
      _clock = null;
      return;
    }
    if (_clock != null) return;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = widget.alerting ? colors.error : colors.primary;
    final foreground = widget.alerting ? colors.onError : colors.onPrimary;

    final status = widget.status();
    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          button: true,
          label: '${widget.title}, $status',
          hint: widget.returnLabel,
          excludeSemantics: true,
          onTap: widget.onTap,
          child: InkWell(
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.alerting
                          ? Icons.sync_rounded
                          : Icons.phone_in_talk_rounded,
                      size: 20,
                      color: foreground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            status,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: foreground,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: foreground,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
