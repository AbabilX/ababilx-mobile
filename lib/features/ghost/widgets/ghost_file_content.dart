import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat-timeline/message_bubble.dart'
    show SignalBubbleColors;
import '../../messages/chat-timeline/signal_bubble_metrics.dart';
import '../../messages/chat_icon.dart';
import '../providers/ghost_state.dart';
import '../screens/ghost_photo_viewer.dart';
import 'ghost_bubble.dart';
import 'ghost_file_row.dart';
import 'ghost_labels.dart';
import 'ghost_timed_photo.dart';

/// A photo or a file inside a Ghost Chat bubble, at the timeline's own media
/// measurements. A photo draws straight from memory; anything else is a row
/// that hands the bytes to another app to open.
class GhostFileContent extends ConsumerWidget {
  const GhostFileContent({super.key, required this.item, required this.colors});

  final GhostItem item;
  final SignalBubbleColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A timed photo is never drawn in the list on the receiving phone, and
    // once viewed it is only a placeholder on both.
    if (item.expired || (item.timed && !item.fromMe)) {
      return GhostTimedPhoto(item: item, colors: colors);
    }
    if (item.isImage && item.complete) {
      return _Photo(item: item, colors: colors);
    }
    return GhostFileRow(item: item, colors: colors);
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.item, required this.colors});

  final GhostItem item;
  final SignalBubbleColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(SignalBubbleMetrics.bigRadius);
    final rules = item.rules;
    // What the sender chose, on the sender's own copy; "View only" on a
    // received photo that may not be saved.
    final badge = item.fromMe
        ? (rules.timer.timed ? ghostTimerLabel(ref, rules.timer) : null)
        : (rules.allowSave ? null : ghostText(ref, 'ghost_view_only'));
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: SignalBubbleMetrics.mediaMaxHeight,
            ),
            child: Image.memory(
              item.bytes!,
              width: SignalBubbleMetrics.mediaMaxWidth,
              fit: BoxFit.cover,
              // Decoded at display size, so the image cache never holds a
              // full-resolution copy the burn would have to chase.
              cacheWidth:
                  (SignalBubbleMetrics.mediaMaxWidth *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              gaplessPlayback: true,
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: () => showGhostPhoto(context, item)),
            ),
          ),
          if (badge != null)
            Positioned(
              left: 8,
              top: 8,
              child: _Badge(
                label: badge,
                icon: item.fromMe
                    ? HugeIcons.strokeRoundedTimer02
                    : HugeIcons.strokeRoundedViewOff,
              ),
            ),
          // The photo is the surface: the time sits on it, as it does in the
          // ordinary timeline, with no strip and no scrim under it.
          Positioned(
            right: 8,
            bottom: 4,
            child: GhostBubbleTime(at: item.at, colors: colors, onMedia: true),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
