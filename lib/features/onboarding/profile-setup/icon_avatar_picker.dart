import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/media/crop_render.dart';
import 'icon_avatar_choices.dart';

/// Icon tiles for the picture step. A tap only reports which tile is
/// selected — the JPEG is rendered when the step saves, on Next.
///
/// What is exported is an ordinary JPEG avatar, so web, desktop and older
/// phones show it with nothing new on the server or in their code.
class IconAvatarPicker extends StatefulWidget {
  const IconAvatarPicker({
    super.key,
    required this.enabled,
    required this.selected,
    required this.onSelect,
  });

  final bool enabled;

  /// The ringed tile, or null when a gallery photo is the current choice.
  final int? selected;

  final ValueChanged<int> onSelect;

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
  double _tile = 52;

  /// The selected tile as JPEG bytes. Null when nothing is selected or the
  /// tile has not been painted yet.
  Future<Uint8List?> renderSelected() {
    final index = widget.selected;
    if (index == null) return Future.value();
    return _render(index);
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
    // Four to a row across the full width; tiles grow to fill the row.
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
                selected: widget.selected == i,
                ring: colors.primary,
                onTap: widget.enabled ? () => widget.onSelect(i) : null,
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
