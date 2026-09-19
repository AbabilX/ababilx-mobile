import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import 'email_auth_actions.dart';
import 'email_auth_repository.dart';
import 'email_auth_ui.dart';
import 'email_code_args.dart';

/// Name, email, password — then a code to the inbox. The account exists only
/// once the code comes back.
class EmailSignUpScreen extends ConsumerStatefulWidget {
  const EmailSignUpScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends ConsumerState<EmailSignUpScreen> {
  final _name = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String t(String key) => AppTranslations.translate(context, ref, key);

  String? _invalid() {
    if (_name.text.trim().isEmpty) return t('name_required');
    if (!looksLikeEmail(_email.text)) return t('email_invalid');
    final length = _password.text.runes.length;
    if (length < 8 || length > 128) return t('password_too_short');
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final invalid = _invalid();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final name = _name.text.trim();
    final email = _email.text.trim();
    try {
      final sent = await ref
          .read(emailAuthRepositoryProvider)
          .signUp(name: name, email: email, password: _password.text);
      if (!mounted) return;
      await context.push(
        '/login/email/code',
        extra: EmailCodeArgs(
          purpose: EmailCodePurpose.signUp,
          email: email,
          sent: sent,
          name: name,
          password: _password.text,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = emailAuthErrorText(context, ref, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EmailAuthScaffold(
    title: t('email_sign_up_title'),
    subtitle: t('email_sign_up_body'),
    children: [
      EmailAuthField(
        controller: _name,
        label: t('name_field'),
        autofillHints: const [AutofillHints.name],
        enabled: !_busy,
      ),
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
        helper: t('password_rule'),
        password: true,
        autofillHints: const [AutofillHints.newPassword],
        enabled: !_busy,
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 8),
      EmailAuthError(_error),
      EmailAuthButton(
        label: t('email_continue'),
        busy: _busy,
        onPressed: _submit,
      ),
    ],
  );
}
