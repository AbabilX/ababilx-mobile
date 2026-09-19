import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import 'email_auth_actions.dart';
import 'email_auth_repository.dart';
import 'email_auth_ui.dart';
import 'email_code_args.dart';

/// Asks for a reset code. Also how an account made with Google gets its
/// first password — the inbox proves ownership either way.
class EmailForgotScreen extends ConsumerStatefulWidget {
  const EmailForgotScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<EmailForgotScreen> createState() => _EmailForgotScreenState();
}

class _EmailForgotScreenState extends ConsumerState<EmailForgotScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
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
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ref
          .read(emailAuthRepositoryProvider)
          .requestReset(email: email);
      if (!mounted) return;
      await context.push(
        '/login/email/code',
        extra: EmailCodeArgs(
          purpose: EmailCodePurpose.reset,
          email: email,
          sent: sent,
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
    title: t('email_reset_title'),
    subtitle: t('email_reset_body'),
    children: [
      EmailAuthField(
        controller: _email,
        label: t('email_field'),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        enabled: !_busy,
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 8),
      EmailAuthError(_error),
      EmailAuthButton(
        label: t('email_send_code'),
        busy: _busy,
        onPressed: _submit,
      ),
    ],
  );
}
