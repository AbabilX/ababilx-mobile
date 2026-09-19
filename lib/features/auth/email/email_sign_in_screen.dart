import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import 'email_auth_actions.dart';
import 'email_auth_repository.dart';
import 'email_auth_ui.dart';

/// Email + password sign-in, with the ways out to "forgot" and "create".
class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _showGoogleHint = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String t(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _error = t('email_invalid'));
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = t('password_too_short'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(emailAuthRepositoryProvider)
          .signIn(email: email, password: _password.text);
      if (!mounted) return;
      await adoptEmailSession(context, ref, session);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = emailAuthErrorText(context, ref, error);
        _showGoogleHint =
            error is EmailAuthException && error.code == 'invalid_credentials';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return EmailAuthScaffold(
      title: t('email_sign_in_title'),
      children: [
        EmailAuthField(
          controller: _email,
          label: t('email_field'),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !_busy,
        ),
        EmailAuthField(
          controller: _password,
          label: t('password_field'),
          password: true,
          autofillHints: const [AutofillHints.password],
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy
                ? null
                : () => context.push(
                    '/login/email/forgot',
                    extra: _email.text.trim(),
                  ),
            child: Text(t('forgot_password')),
          ),
        ),
        const SizedBox(height: 8),
        EmailAuthError(_error),
        if (_showGoogleHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              t('email_google_hint'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        EmailAuthButton(
          label: t('email_sign_in'),
          busy: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t('no_account_prompt')),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => context.push(
                      '/login/email/new',
                      extra: _email.text.trim(),
                    ),
              child: Text(t('create_account')),
            ),
          ],
        ),
      ],
    );
  }
}
