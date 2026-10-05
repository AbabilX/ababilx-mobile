import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/store/share_records.dart';
import '../providers/local_share_providers.dart';

/// How much of [file] has moved, 0–1, or null when it is not moving (done,
/// failed, or simply waiting its turn with nothing transferred yet).
double? shareFileFraction(
  WidgetRef ref,
  ShareMessageRecord message,
  ShareFileRecord file,
) {
  if (file.done || file.size <= 0) return null;
  final active =
      message.status == ShareMessageStatus.sending ||
      message.status == ShareMessageStatus.receiving;
  if (!active) return null;
  final live = ref.watch(localShareProgressProvider(message.id)).valueOrNull;
  final bytes = live?.fileBytes[file.id] ?? file.bytesDone;
  return (bytes / file.size).clamp(0.0, 1.0);
}

/// A ring over a photo or a file glyph while its bytes are on the way.
class ShareProgressRing extends StatelessWidget {
  const ShareProgressRing({super.key, required this.fraction, this.size = 40});

  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        shape: BoxShape.circle,
      ),
      child: CircularProgressIndicator(
        value: fraction <= 0 ? null : fraction,
        strokeWidth: 2.5,
        color: Colors.white,
        backgroundColor: Colors.white24,
      ),
    );
  }
}
