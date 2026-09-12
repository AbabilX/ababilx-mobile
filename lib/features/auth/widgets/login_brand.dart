import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginBrand extends StatelessWidget {
  const LoginBrand({
    super.key,
    required this.isLoading,
    required this.subtitle,
  });

  final bool isLoading;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const title = 'AbabilX';
    final titleStyle = GoogleFonts.fredoka(
      fontSize: 38,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1,
      color: colors.primary,
      shadows: [
        Shadow(
          color: colors.primary.withValues(alpha: 0.14),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Column(
      children: [
        Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.outline, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
              ),
            )
            .animate(
              onPlay: isLoading
                  ? (controller) => controller.repeat(reverse: true)
                  : null,
            )
            .fadeIn(duration: 500.ms)
            .scale(
              begin: isLoading ? const Offset(1, 1) : const Offset(0.8, 0.8),
              end: isLoading ? const Offset(1.08, 1.08) : const Offset(1, 1),
              duration: isLoading ? 650.ms : 500.ms,
              curve: isLoading ? Curves.easeInOut : Curves.easeOutBack,
            ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: 260.ms,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: isLoading
              ? TweenAnimationBuilder<int>(
                  key: const ValueKey('loading-title'),
                  tween: IntTween(begin: 0, end: title.length),
                  duration: 1200.ms,
                  curve: Curves.easeOut,
                  builder: (_, value, _) => Text(
                    title.substring(0, value.clamp(0, title.length)),
                    style: titleStyle,
                  ),
                )
              : Text(
                  title,
                  key: const ValueKey('idle-title'),
                  style: titleStyle,
                ).animate().fadeIn(delay: 150.ms),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            height: 1.45,
            letterSpacing: 0.05,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 250.ms),
      ],
    );
  }
}
