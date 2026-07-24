import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../chat_icon.dart';

class YouSheetBar extends StatelessWidget {
  const YouSheetBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const ChatIcon(HugeIcons.strokeRoundedCancel01, size: 22),
          ),
          const Expanded(
            child: Text(
              'You',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
