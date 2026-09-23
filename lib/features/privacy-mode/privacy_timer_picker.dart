import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../ghost/protocol/ghost_item_rules.dart';
import '../ghost/widgets/ghost_labels.dart';
import '../messages/chat_icon.dart';

/// The timer list Ghost Chat's send preview opens: off, view once, 5/10/30 s.
Future<GhostViewTimer?> showPrivacyTimerPicker(
  BuildContext context,
  WidgetRef ref,
  GhostViewTimer current,
) => showModalBottomSheet<GhostViewTimer>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(title: Text(ghostText(ref, 'ghost_timer_title'))),
        for (final timer in GhostViewTimer.values)
          ListTile(
            leading: ChatIcon(
              timer.timed
                  ? HugeIcons.strokeRoundedTimer02
                  : HugeIcons.strokeRoundedView,
            ),
            title: Text(ghostTimerLabel(ref, timer)),
            trailing: timer == current ? const Icon(Icons.check_rounded) : null,
            onTap: () => Navigator.of(sheet).pop(timer),
          ),
      ],
    ),
  ),
);
