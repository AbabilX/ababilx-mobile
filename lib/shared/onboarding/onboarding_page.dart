import 'package:flutter/material.dart';

/// The frame every first-run screen is drawn in — the reference Android app's
/// `RegistrationScreen`: a large left-aligned title, a muted subtitle, the
/// screen's own content scrolling under them, and an optional bottom bar that
/// lifts (shadow) only while there is more content above it to scroll to.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.bottom,
    this.gap = 40,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Pinned under the scrolling part: buttons, a quiet skip link.
  final Widget? bottom;

  /// Space between the heading and [children].
  final double gap;

  /// The reference app's `horizontalGutters()`.
  static const gutter = 24.0;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _moreBelow = false;

  bool _onMetrics(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 0;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottom = widget.bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  OnboardingPage.gutter,
                  40,
                  OnboardingPage.gutter,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: colors.onSurface,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.subtitle!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: widget.gap),
                    ...widget.children,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (bottom != null)
          Material(
            color: colors.surface,
            elevation: _moreBelow ? 8 : 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OnboardingPage.gutter,
                8,
                OnboardingPage.gutter,
                24,
              ),
              child: bottom,
            ),
          ),
      ],
    );
  }
}
