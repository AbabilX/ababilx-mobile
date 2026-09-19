import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_sign_in_action.dart';
import '../widgets/google_sign_in_action.dart';
import '../widgets/login_brand.dart';
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
    final error = authState.error?.toString().replaceAll('Exception: ', '');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  children: [
                    LoginBrand(
                      isLoading: isLoading,
                      subtitle: AppTranslations.translate(
                        context,
                        ref,
                        'login_subtitle',
                      ),
                    ),
                    const SizedBox(height: 32),
                    LoginGoogleAction(
                      isLoading: isLoading,
                      error: error,
                      label: AppTranslations.translate(
                        context,
                        ref,
                        'continue_google',
                      ),
                      onPressed: () => runGoogleSignIn(context, ref),
                    ),
                    if (!isLoading) ...[
                      const SizedBox(height: 12),
                      LoginEmailAction(
                        label: AppTranslations.translate(
                          context,
                          ref,
                          'continue_email',
                        ),
                        onPressed: () => context.push('/login/email'),
                      ),
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
