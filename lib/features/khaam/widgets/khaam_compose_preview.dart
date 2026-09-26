import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/khaam_covers.dart';
import 'khaam_card.dart';
import 'khaam_caption.dart';

/// The compose screen's preview IS the card the other person will open —
/// same envelope, same "from" line, same message —
/// drawn with the foil already off. The memory photo fills the envelope's
/// upper panel down to the flap, exactly as it was cropped; the pills over
/// it add, change or remove it.
class KhaamComposePreview extends StatelessWidget {
  const KhaamComposePreview({
    super.key,
    required this.cover,
    required this.width,
    required this.fromLabel,
    required this.senderName,
    required this.senderAvatar,
    required this.message,
    required this.photo,
    required this.addLabel,
    required this.changeLabel,
    required this.onPick,
    required this.onRemove,
  });

  final KhaamCover cover;
  final double width;
  final String fromLabel;
  final String senderName;
  final String? senderAvatar;
  final String message;
  final Uint8List? photo;
  final String addLabel;
  final String changeLabel;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = photo;
    return Center(
      child: KhaamCard(
        cover: cover,
        width: width,
        fromLabel: fromLabel,
        senderName: senderName,
        senderAvatar: senderAvatar,
        photo: bytes == null
            ? null
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        envelopeOverlay: Positioned(
          top: 10,
          right: 10,
          child: bytes == null
              ? _BandPill(
                  icon: HugeIcons.strokeRoundedImageAdd01,
                  label: addLabel,
                  onTap: onPick,
                )
              : Row(
                  children: [
                    _BandPill(
                      icon: HugeIcons.strokeRoundedImage01,
                      label: changeLabel,
                      onTap: onPick,
                    ),
                    const SizedBox(width: 6),
                    _BandPill(
                      icon: HugeIcons.strokeRoundedCancel01,
                      onTap: onRemove,
                    ),
                  ],
                ),
        ),
        caption: KhaamCaption(cover: cover, text: message.trim()),
      ),
    );
  }
}

/// A small dark pill over the top area — readable on any cover or photo.
class _BandPill extends StatelessWidget {
  const _BandPill({required this.icon, required this.onTap, this.label});

  final List<List<dynamic>> icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 8 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatIcon(icon, size: 16, color: Colors.white),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
