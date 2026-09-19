import 'package:flutter/material.dart';

import '../../core/router/root_back.dart';
import 'preview_icon.dart';

/// HugeIcons back chevron — use inside custom [IconButton]s (search, toolbars).
class AppBarBackIcon extends StatelessWidget {
  const AppBarBackIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PreviewIcon(PreviewIcons.back, color: colors.onSurface);
  }
}

/// AppBar leading — same icon as [ThemeData.actionIconTheme] back builder.
class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const AppBarBackIcon(),
      onPressed: onPressed ?? () => popOrGoHome(context),
    );
  }
}
