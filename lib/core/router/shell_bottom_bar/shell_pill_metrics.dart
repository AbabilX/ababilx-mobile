import 'package:flutter/widgets.dart';

/// Shared sizing for the floating app navigation capsules.
abstract final class ShellPillMetrics {
  static const double height = 64;

  /// Gap between the bar and the last row of content above it.
  static const double contentGap = 24;

  /// Bottom padding so list content is not covered by the fixed bar.
  ///
  /// The bar sits inside a `SafeArea`, so its real height is this plus
  /// whatever the system reserves for the gesture handle — 0 on a
  /// three-button phone, around 34 on gesture navigation, more on a few OEM
  /// skins. Padding a list by the constant alone leaves the last item tucked
  /// under the pill on exactly the devices most people are using now, which is
  /// why [contentBottom] is what call sites should use.
  static const double contentBottomInset = height + contentGap;

  static double contentBottom(BuildContext context) =>
      contentBottomInset + MediaQuery.viewPaddingOf(context).bottom;
}
