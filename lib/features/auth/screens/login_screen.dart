import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final error = authState.error?.toString();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Brand Logo - Symmetrical Squircle with Clean Flat Border
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colors.outline,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: colors.primary,
                      size: 48,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

                const SizedBox(height: 32),

                // Emphasized Title (Editorial Outfit Typography)
                Text(
                  'AbabilX',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 12),

                // Subtitle (Jakarta Sans) - Bilingual Translation
                Text(
                  AppTranslations.translate(context, ref, 'login_subtitle'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFCAC4D0),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 48),

                // Google Sign-In Button (Chunky M3 Tonal Stadium style)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(authProvider.notifier)
                            .signInWithGoogle(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.surfaceContainerLow,
                      foregroundColor: colors.onSurface,
                      elevation: 0,
                      side: BorderSide(color: colors.outline, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: colors.primary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Styled Google Icon Squircle with Lavender background and deep purple text
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8DEF8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: Color(0xFF381E72),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                AppTranslations.translate(context, ref, 'continue_google'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
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
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.error.withOpacity(0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      error.replaceAll('Exception: ', ''),
                      style: TextStyle(
                          color: colors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
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
    );
  }
}
