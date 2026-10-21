import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../device/start_new_chat_action.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_sign_in_action.dart';
import '../widgets/google_sign_in_action.dart';
import '../widgets/login_brand.dart';
import '../widgets/login_error_note.dart';
import '../widgets/onboarding_gate.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const OnboardingGate(child: _LoginContent());
}

enum _LoginWay { newChat, google }

/// Three ways in, always all three, in this order (user's decision,
/// 2026-10-20): Start New Chat (a new account, nothing asked), Google and
/// email + password (existing accounts, same id and data as before).
class _LoginContent extends ConsumerStatefulWidget {
  const _LoginContent();

  @override
  ConsumerState<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends ConsumerState<_LoginContent> {
  _LoginWay? _running;

  Future<void> _run(
    _LoginWay way,
    Future<void> Function(BuildContext, WidgetRef) action,
  ) async {
    setState(() => _running = way);
    try {
      await action(context, ref);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final error = authState.error?.toString().replaceAll('Exception: ', '');
    String t(String key) => AppTranslations.translate(context, ref, key);

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
                      subtitle: t('login_subtitle'),
                    ),
                    const SizedBox(height: 32),
                    StartNewChatAction(
                      label: t('start_new_chat'),
                      busy: isLoading && _running == _LoginWay.newChat,
                      onPressed: isLoading
                          ? null
                          : () => _run(_LoginWay.newChat, runStartNewChat),
                    ),
                    const SizedBox(height: 12),
                    LoginGoogleAction(
                      label: t('sign_in_google'),
                      busy: isLoading && _running == _LoginWay.google,
                      onPressed: isLoading
                          ? null
                          : () => _run(_LoginWay.google, runGoogleSignIn),
                    ),
                    const SizedBox(height: 8),
                    LoginEmailAction(
                      label: t('sign_in_email_password'),
                      onPressed: isLoading
                          ? null
                          : () => context.push('/login/email'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 20),
                      LoginErrorNote(message: error),
                    ],
                    const SizedBox(height: 32),
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
