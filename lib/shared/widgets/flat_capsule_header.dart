import 'package:flutter/material.dart';

import '../../features/messages/chat-pins/pinned_messages_chrome.dart';
import '../../features/messages/chat_icon.dart';
import 'app_bar_back_button.dart';

/// A page header that sits flat on the page: a round back button on the left, the
/// page's title written flat in the middle, an optional labelled action
/// capsule on the right. The app's frosted capsules on a flat bar: it does not
/// float over the page.
class FlatCapsuleHeader extends StatelessWidget {
  const FlatCapsuleHeader({
    super.key,
    required this.title,
    this.action,
    this.bottomPadding = 8,
  });

  /// Written flat in the middle, no capsule behind it.
  final Widget title;
  final Widget? action;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.viewPaddingOf(context).top;
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, bottomPadding),
        child: Row(
          children: [
            HeaderPill(
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(child: AppBarBackIcon()),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(child: title),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// One line of the header, in the header's own type.
class FlatHeaderLabel extends StatelessWidget {
  const FlatHeaderLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: color ?? theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// The right-hand capsule: a glyph and what it does, in words.
class FlatHeaderAction extends StatelessWidget {
  const FlatHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tint,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onPressed;

  /// Null draws it in the header's own ink (delete passes the error colour).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return HeaderPill(
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatIcon(icon, size: 20, color: tint ?? colors.onSurface),
                const SizedBox(width: 6),
                FlatHeaderLabel(label, color: tint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
