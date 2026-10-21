import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/media/crop_render.dart';
import 'icon_avatar_choices.dart';

/// The quick way past the picture step: tap an icon and it becomes the
/// profile picture. Each tile is drawn once more at [_exportPixels] and saved
/// as an ordinary JPEG avatar, so web, desktop and older phones show it
/// with nothing new on the server or in their code.
class IconAvatarPicker extends StatefulWidget {
  const IconAvatarPicker({
    super.key,
    required this.enabled,
    required this.onPicked,
  });

  final bool enabled;

  /// JPEG bytes of the chosen tile, square.
  final Future<void> Function(Uint8List jpeg) onPicked;

  @override
  State<IconAvatarPicker> createState() => IconAvatarPickerState();
}

const double _exportPixels = 512;
const double _gap = 14;
const int _perRow = 4;
// The 3px padding and 2px ring on each side of a tile.
const double _ringSpace = 10;

class IconAvatarPickerState extends State<IconAvatarPicker> {
  final _keys = List.generate(iconAvatarChoices.length, (_) => GlobalKey());
  int? _picked;
  double _tile = 52;

  /// Skip on the picture step: one of the icons, at random, as JPEG bytes.
  /// The caller uploads it; nothing here waits on the network.
  Future<Uint8List?> renderRandom() =>
      _render(Random.secure().nextInt(iconAvatarChoices.length));

  Future<void> _pick(int index) async {
    final jpeg = await _render(index);
    if (jpeg == null || !mounted) return;
    setState(() => _picked = index);
    await widget.onPicked(jpeg);
  }

  Future<Uint8List?> _render(int index) async {
    final boundary =
        _keys[index].currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // The tile is vector, so drawing it again at a higher ratio is as sharp
    // as drawing it at that size in the first place.
    final image = await boundary.toImage(pixelRatio: _exportPixels / _tile);
    final jpeg = await cropToJpeg(
      image: image,
      source: ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      outputSize: const ui.Size(_exportPixels, _exportPixels),
      quality: 90,
    );
    image.dispose();
    return jpeg;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Four to a row across the full width: 12 icons as 4 × 3, never
    // 5 + 5 + 2, and the tiles grow to fill the row instead of leaving a gap.
    return LayoutBuilder(
      builder: (context, box) {
        _tile = ((box.maxWidth - (_perRow - 1) * _gap) / _perRow - _ringSpace)
            .clamp(40, 80);
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var i = 0; i < iconAvatarChoices.length; i++)
              _IconTile(
                boundaryKey: _keys[i],
                choice: iconAvatarChoices[i],
                size: _tile,
                selected: _picked == i,
                ring: colors.primary,
                onTap: widget.enabled ? () => _pick(i) : null,
              ),
          ],
        );
      },
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.boundaryKey,
    required this.choice,
    required this.size,
    required this.selected,
    required this.ring,
    required this.onTap,
  });

  final GlobalKey boundaryKey;
  final IconAvatarChoice choice;
  final double size;
  final bool selected;
  final Color ring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? ring : Colors.transparent,
            width: 2,
          ),
        ),
        // The circle is only how the tile is shown here. What is exported
        // is the square inside the boundary, like every other avatar: the
        // circle is a mask each client applies when drawing it.
        child: ClipOval(
          child: RepaintBoundary(
            key: boundaryKey,
            child: Container(
              width: size,
              height: size,
              color: choice.background,
              alignment: Alignment.center,
              child: HugeIcon(
                icon: choice.icon,
                size: size * 0.5,
                color: choice.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
