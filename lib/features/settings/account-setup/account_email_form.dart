import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../auth/email/email_auth_actions.dart';
import '../../auth/email/email_auth_repository.dart';
import '../../auth/email/email_auth_ui.dart';
import '../../profile/providers/profile_provider.dart';
import 'account_email_code.dart';
import 'account_email_repository.dart';

/// Add an email: type it, get a 6-digit code there, enter it. With
/// [withPassword] the code step also sets a password, so the account can be
/// signed into again on another phone. Used by Discovery (email only) and
/// "Secure your account" (email + password).
class AccountEmailForm extends ConsumerStatefulWidget {
  const AccountEmailForm({super.key, this.withPassword = false, this.onDone});

  final bool withPassword;
  final VoidCallback? onDone;

  @override
  ConsumerState<AccountEmailForm> createState() => _AccountEmailFormState();
}

class _AccountEmailFormState extends ConsumerState<AccountEmailForm> {
  final _email = TextEditingController();
  EmailCodeSent? _sent;
  bool _busy = false;
  String? _error;

  String t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final address = _email.text.trim();
    if (!address.contains('@') || !address.contains('.')) {
      setState(() => _error = t('email_err_invalid_email'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ref
          .read(accountEmailRepositoryProvider)
          .sendCode(address);
      if (mounted) setState(() => _sent = sent);
    } catch (error) {
      if (mounted) {
        setState(() => _error = emailAuthErrorText(context, ref, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _added() async {
    await ref.read(profileProvider.notifier).refresh();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    if (sent != null) {
      return AccountEmailCode(
        email: _email.text.trim(),
        sent: sent,
        withPassword: widget.withPassword,
        onChangeEmail: () => setState(() => _sent = null),
        onSaved: _added,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmailAuthField(
          controller: _email,
          label: t('email_field'),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !_busy,
          onSubmitted: (_) => _send(),
        ),
        EmailAuthError(_error),
        EmailAuthButton(
          label: t('email_send_code'),
          busy: _busy,
          onPressed: _send,
        ),
      ],
    );
  }
}
