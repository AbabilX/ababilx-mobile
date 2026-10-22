import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../device/start_new_chat_action.dart';
import '../providers/auth_provider.dart';
import '../widgets/continue_with_account_action.dart';
import '../widgets/login_brand.dart';
import '../widgets/login_error_note.dart';
import '../widgets/onboarding_gate.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const OnboardingGate(child: _LoginContent());
}

enum _LoginWay { newChat, continueAccount }

/// Two choices on the start screen (user's call, 2026-10-23): Start New Chat
/// (filled, as before), and Continue with account → sheet with Google and
/// email + password for existing accounts.
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
    final continueBusy = isLoading && _running == _LoginWay.continueAccount;

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
                    ContinueWithAccountAction(
                      label: t('continue_with_account'),
                      onPressed: isLoading || continueBusy
                          ? null
                          : () => _run(
                                _LoginWay.continueAccount,
                                runContinueWithAccount,
                              ),
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
