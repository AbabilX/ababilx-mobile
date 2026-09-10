import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/app_translations.dart';
import '../providers/auth_provider.dart';
import '../widgets/onboarding_gate.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const OnboardingGate(child: _LoginContent());
}

class _LoginContent extends ConsumerWidget {
  const _LoginContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final error = authState.error?.toString();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brandStyle = GoogleFonts.fredoka(
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

    const brandTitle = 'AbabilX';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_background_v2.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: 'AbabilX community illustration',
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // The artwork is full-screen; the controls stay in its clear lower area.
                    Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: colors.outline,
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        .animate(
                          onPlay: isLoading
                              ? (controller) => controller.repeat(reverse: true)
                              : null,
                        )
                        .fadeIn(duration: 500.ms)
                        .scale(
                          begin: isLoading
                              ? const Offset(1, 1)
                              : const Offset(0.8, 0.8),
                          end: isLoading
                              ? const Offset(1.08, 1.08)
                              : const Offset(1, 1),
                          duration: isLoading ? 650.ms : 500.ms,
                          curve: isLoading
                              ? Curves.easeInOut
                              : Curves.easeOutBack,
                        ),

                    const SizedBox(height: 18),

                    // Rounded wordmark complements the friendly illustration.
                    AnimatedSwitcher(
                      duration: 260.ms,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: isLoading
                          ? TweenAnimationBuilder<int>(
                              key: const ValueKey('loading-title'),
                              tween: IntTween(begin: 0, end: brandTitle.length),
                              duration: 1200.ms,
                              curve: Curves.easeOut,
                              builder: (context, value, _) {
                                final safeLength = value.clamp(
                                  0,
                                  brandTitle.length,
                                );
                                return Text(
                                  brandTitle.substring(0, safeLength),
                                  style: brandStyle,
                                );
                              },
                            )
                          : Text(
                              brandTitle,
                              key: const ValueKey('idle-title'),
                              style: brandStyle,
                            ).animate().fadeIn(delay: 150.ms),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle (Jakarta Sans) - Bilingual Translation
                    Text(
                      AppTranslations.translate(context, ref, 'login_subtitle'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        letterSpacing: 0.05,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 32),

                    // Google Sign-In Button (Hidden while loading, reappears on failure)
                    AnimatedSwitcher(
                          duration: 280.ms,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.vertical,
                                child: child,
                              ),
                            );
                          },
                          child: isLoading
                              ? const SizedBox(
                                  key: ValueKey('login-hidden'),
                                  height: 0,
                                )
                              : SizedBox(
                                  key: const ValueKey('login-button'),
                                  width: double.infinity,
                                  height: 56,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => ref
                                          .read(authProvider.notifier)
                                          .signInWithGoogle(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            colors.surfaceContainerLowest,
                                        foregroundColor: colors.onSurface,
                                        elevation: 0,
                                        side: BorderSide(
                                          color: colors.primary.withValues(
                                            alpha: 0.18,
                                          ),
                                          width: 1.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Google sign-in indicator.
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: colors.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'G',
                                                style: TextStyle(
                                                  color: colors
                                                      .onSecondaryContainer,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Text(
                                            AppTranslations.translate(
                                              context,
                                              ref,
                                              'continue_google',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        )
                        .animate()
                        .fadeIn(delay: 350.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                    if (error != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.error.withValues(alpha: 0.2),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          error.replaceAll('Exception: ', ''),
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().shake(delay: 100.ms),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
