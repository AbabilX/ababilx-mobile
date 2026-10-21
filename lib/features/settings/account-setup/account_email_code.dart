import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/email/email_auth_actions.dart';
import '../../auth/email/email_auth_repository.dart';
import '../../auth/email/email_auth_ui.dart';
import 'account_code_field.dart';
import 'account_email_repository.dart';

/// The code step of adding an email: the 6 digits, a password when asked
/// for, resend on the server's cooldown, and a way back to fix a typo.
class AccountEmailCode extends ConsumerStatefulWidget {
  const AccountEmailCode({
    super.key,
    required this.email,
    required this.sent,
    required this.withPassword,
    required this.onChangeEmail,
    required this.onSaved,
  });

  final String email;
  final EmailCodeSent sent;
  final bool withPassword;
  final VoidCallback onChangeEmail;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<AccountEmailCode> createState() => _AccountEmailCodeState();
}

class _AccountEmailCodeState extends ConsumerState<AccountEmailCode> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  late int _resendIn = widget.sent.resendIn.inSeconds;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  String t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void initState() {
    super.initState();
    _countdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _countdown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) timer.cancel();
      if (mounted) {
        setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      final sent = await ref
          .read(accountEmailRepositoryProvider)
          .sendCode(widget.email);
      if (!mounted) return;
      setState(() => _resendIn = sent.resendIn.inSeconds);
      _countdown();
      showAppToast(context, t('email_code_resent'));
    } catch (error) {
      if (mounted) {
        setState(() => _error = emailAuthErrorText(context, ref, error));
      }
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = t('code_invalid_length'));
      return;
    }
    if (widget.withPassword) {
      final length = _password.text.runes.length;
      if (length < 8 || length > 128) {
        setState(() => _error = t('password_too_short'));
        return;
      }
      if (_repeat.text != _password.text) {
        setState(() => _error = t('password_mismatch'));
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountEmailRepositoryProvider)
          .confirm(
            email: widget.email,
            code: code,
            password: widget.withPassword ? _password.text : '',
          );
      await widget.onSaved();
    } catch (error) {
      if (mounted) {
        setState(() => _error = emailAuthErrorText(context, ref, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('email_code_body').replaceAll('{email}', widget.email),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AccountCodeField(
            controller: _code,
            label: t('email_code_field'),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          if (widget.withPassword) ...[
            EmailAuthField(
              controller: _password,
              label: t('new_password_field'),
              helper: t('password_rule'),
              password: true,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_busy,
            ),
            EmailAuthField(
              controller: _repeat,
              label: t('password_repeat_field'),
              password: true,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
            ),
          ],
          EmailAuthError(_error),
          EmailAuthButton(
            label: t('account_email_save'),
            busy: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _busy ? null : widget.onChangeEmail,
                child: Text(t('account_email_change')),
              ),
              TextButton(
                onPressed: _busy || _resendIn > 0 ? null : _resend,
                child: Text(
                  _resendIn > 0
                      ? t(
                          'email_code_resend_in',
                        ).replaceAll('{seconds}', '$_resendIn')
                      : t('email_code_resend'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
