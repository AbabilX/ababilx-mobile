import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A HugeIcons glyph. The package models an icon as its path data, not as an
/// [IconData], so it cannot go into a plain [Icon].
typedef CallGlyph = List<List<dynamic>>;

/// Every icon the call surface uses, named by role rather than by shape, so a
/// swap happens once here instead of across a dozen widgets.
class CallIcons {
  const CallIcons._();

  static const CallGlyph micOn = HugeIcons.strokeRoundedMic01;
  static const CallGlyph micMuted = HugeIcons.strokeRoundedMicOff01;
  static const CallGlyph leave = HugeIcons.strokeRoundedCallEnd01;
  static const CallGlyph screenShare =
      HugeIcons.strokeRoundedComputerScreenShare;
  static const CallGlyph raiseHand = HugeIcons.strokeRoundedWavingHand01;
  static const CallGlyph reaction = HugeIcons.strokeRoundedSmile;
  static const CallGlyph participants = HugeIcons.strokeRoundedUserMultiple;
  static const CallGlyph gridView = HugeIcons.strokeRoundedGridView;
  static const CallGlyph speakerView = HugeIcons.strokeRoundedLayout01;
  static const CallGlyph minimize = HugeIcons.strokeRoundedArrowDown01;
  static const CallGlyph close = HugeIcons.strokeRoundedCancel01;
  static const CallGlyph speakerOn = HugeIcons.strokeRoundedVolumeHigh;
  static const CallGlyph speakerOff = HugeIcons.strokeRoundedEar;
  static const CallGlyph bluetoothAudio = HugeIcons.strokeRoundedBluetooth;
  static const CallGlyph wiredHeadset = HugeIcons.strokeRoundedHeadphones;
  static const CallGlyph join = HugeIcons.strokeRoundedHeadphones;
  static const CallGlyph alert = HugeIcons.strokeRoundedAlert01;
}

/// Thin [HugeIcon] wrapper so call sites read like an [Icon].
class CallIcon extends StatelessWidget {
  const CallIcon(this.icon, {super.key, this.size = 22, this.color});

  final CallGlyph icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => HugeIcon(
    icon: icon,
    size: size,
    color: color ?? IconTheme.of(context).color ?? Colors.white,
  );
}
