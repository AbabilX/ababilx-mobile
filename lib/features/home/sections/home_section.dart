import 'package:flutter/material.dart';

/// A Home block: a bold title (and an optional "See all ›" on the right),
/// then [child]. No dividers, no fold — space separates blocks.
class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (actionLabel != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A horizontal row for Home, sized by its children's own [height].
class HomeStrip extends StatelessWidget {
  const HomeStrip({
    super.key,
    required this.height,
    required this.children,
    this.gap = 10,
  });

  final double height;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: children.length,
      separatorBuilder: (_, _) => SizedBox(width: gap),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

/// A face over a name, for the Pinned and Talk-again rows.
class HomeFaceTile extends StatelessWidget {
  const HomeFaceTile({
    super.key,
    required this.avatar,
    required this.label,
    required this.onTap,
    this.bold = false,
    this.face = 60,
    this.width = 72,
  });

  /// What the row reserves; scaled with the phone's font.
  static double heightFor(BuildContext context, {double face = 60}) =>
      face + 6 + MediaQuery.textScalerOf(context).scale(12) * 1.3 + 6;

  final Widget avatar;
  final String label;
  final VoidCallback onTap;
  final bool bold;
  final double face;
  final double width;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: width,
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A rounded capsule: a picture filling its full height on the left, so the
/// picture's circle IS the capsule's left end, then a label and an optional
/// trailing action. Used for nearby devices.
class HomeCapsule extends StatelessWidget {
  const HomeCapsule({
    super.key,
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  static double heightFor(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(14) * 1.3).clamp(40, 80) + 12;

  /// Built at the capsule's height: a circle that size has the stadium's own
  /// radius, so the two left curves are one.
  final Widget Function(double size) leading;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = heightFor(context);
    return Material(
      color: colors.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: size,
          child: Padding(
            padding: EdgeInsets.only(right: trailing == null ? 16 : 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading(size),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
