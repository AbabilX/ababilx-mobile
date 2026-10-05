import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// HugeIcons path data. The package is not [IconData], so a wrapper is required.
typedef PreviewGlyph = List<List<dynamic>>;

/// Thin [HugeIcon] so preview chrome reads like an [Icon].
class PreviewIcon extends StatelessWidget {
  const PreviewIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.2,
  });

  final PreviewGlyph icon;
  final double size;
  final Color? color;

  /// Thinner than the package default (1.5) so chrome reads light, not bold.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      size: size,
      color: color ?? IconTheme.of(context).color ?? Colors.white,
      strokeWidth: strokeWidth,
    );
  }
}

/// Preview chrome glyphs — free stroke-rounded set only.
abstract final class PreviewIcons {
  static const PreviewGlyph back = HugeIcons.strokeRoundedArrowLeft01;
  static const PreviewGlyph save = HugeIcons.strokeRoundedDownload04;
  static const PreviewGlyph rotate = HugeIcons.strokeRoundedRotateClockwise;
  static const PreviewGlyph mute = HugeIcons.strokeRoundedVolumeOff;
  static const PreviewGlyph unmute = HugeIcons.strokeRoundedVolumeHigh;
  static const PreviewGlyph open = HugeIcons.strokeRoundedLinkSquare01;
  static const PreviewGlyph print = HugeIcons.strokeRoundedPrinter;
  static const PreviewGlyph share = HugeIcons.strokeRoundedShare01;
  static const PreviewGlyph play = HugeIcons.strokeRoundedPlay;
  static const PreviewGlyph pause = HugeIcons.strokeRoundedPause;
  static const PreviewGlyph chevron = HugeIcons.strokeRoundedArrowRight01;
  static const PreviewGlyph pdf = HugeIcons.strokeRoundedPdf01;
  static const PreviewGlyph word = HugeIcons.strokeRoundedDoc01;
  static const PreviewGlyph sheet = HugeIcons.strokeRoundedXls01;
  static const PreviewGlyph slides = HugeIcons.strokeRoundedPpt01;
  static const PreviewGlyph zip = HugeIcons.strokeRoundedFileZip;
  static const PreviewGlyph file = HugeIcons.strokeRoundedFile01;
  static const PreviewGlyph more = HugeIcons.strokeRoundedMoreVertical;
  static const PreviewGlyph videoOff = HugeIcons.strokeRoundedVideoOff;
  static const PreviewGlyph brokenImage =
      HugeIcons.strokeRoundedImageNotFound01;
  static const PreviewGlyph playCircle = HugeIcons.strokeRoundedPlayCircle;
}
