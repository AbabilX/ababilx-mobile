import 'package:flutter/material.dart';

import '../signals/call_signals.dart';
import 'call_surface.dart';

/// The eight reactions, in the same order as web. Opened from the call bar.
Future<void> showReactionPicker(
  BuildContext context,
  ValueChanged<String> onPick,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: CallColors.of(context).panel,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final emoji in callReactions)
            InkResponse(
              onTap: () {
                onPick(emoji);
                Navigator.of(sheetContext).pop();
              },
              radius: 28,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
        ],
      ),
    ),
  ),
);
