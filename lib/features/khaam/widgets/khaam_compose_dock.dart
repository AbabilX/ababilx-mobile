import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router/shell_bottom_bar/nav_tab_item.dart';

/// The compose page's dock items, drawn as the shell's nav tabs.
class JPackComposeDock extends StatelessWidget {
  const JPackComposeDock({
    super.key,
    required this.langLabel,
    required this.captionsLabel,
    required this.coverLabel,
    required this.onLang,
    required this.onCaptions,
    required this.onCover,
  });

  final String langLabel;
  final String captionsLabel;
  final String coverLabel;
  final VoidCallback onLang;
  final VoidCallback onCaptions;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavTabItem(
          icon: HugeIcons.strokeRoundedLanguageSquare,
          selectedIcon: HugeIcons.strokeRoundedLanguageSquare,
          label: langLabel,
          selected: false,
          onTap: () {
            HapticFeedback.selectionClick();
            onLang();
          },
        ),
        NavTabItem(
          icon: HugeIcons.strokeRoundedDice,
          selectedIcon: HugeIcons.strokeRoundedDice,
          label: captionsLabel,
          selected: false,
          onTap: () {
            HapticFeedback.selectionClick();
            onCaptions();
          },
        ),
        NavTabItem(
          icon: HugeIcons.strokeRoundedImage01,
          selectedIcon: HugeIcons.strokeRoundedImage01,
          label: coverLabel,
          selected: false,
          onTap: onCover,
        ),
      ],
    );
  }
}
