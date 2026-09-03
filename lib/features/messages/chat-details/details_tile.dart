import 'package:flutter/material.dart';

/// A settings row on the details screen: outline icon, title, optional value
/// underneath. Signal states the current value as the subtitle ("Off", "On")
/// rather than putting a control on the right, so a row stays one tap target.
class DetailsTile extends StatelessWidget {
  const DetailsTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final Widget icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = destructive ? colors.error : colors.onSurface;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minLeadingWidth: 28,
      leading: IconTheme.merge(
        data: IconThemeData(color: tint, size: 24),
        child: icon,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: tint,
        ),
      ),
      subtitle: value == null
          ? null
          : Text(
              value!,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
      trailing: trailing,
    );
  }
}

/// The hairline between two groups of rows. Signal separates sections with a
/// full-width divider and space, never a card outline.
class DetailsSectionGap extends StatelessWidget {
  const DetailsSectionGap({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .5),
    ),
  );
}
