import 'package:flutter/material.dart';

import '../../core/router/root_back.dart';
import 'preview_icon.dart';

/// AppBar leading — same HugeIcons chevron as [ThemeData.actionIconTheme].
class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      icon: PreviewIcon(PreviewIcons.back, color: colors.onSurface),
      onPressed: onPressed ?? () => popOrGoHome(context),
    );
  }
}
