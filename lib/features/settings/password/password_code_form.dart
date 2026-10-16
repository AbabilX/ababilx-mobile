import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/email/email_auth_actions.dart';
import '../../auth/email/email_auth_repository.dart';
import '../../auth/email/email_auth_ui.dart';
import 'password_repository.dart';

/// The code that was just emailed, the new password twice, and a resend on
/// the server's cooldown. Saving keeps this session signed in.
class PasswordCodeForm extends ConsumerStatefulWidget {
  const PasswordCodeForm({
    super.key,
    required this.sent,
    required this.onSaved,
  });

  final EmailCodeSent sent;
  final VoidCallback onSaved;

  @override
  ConsumerState<PasswordCodeForm> createState() => _PasswordCodeFormState();
}

class _PasswordCodeFormState extends ConsumerState<PasswordCodeForm> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  late String _masked = widget.sent.maskedEmail;
  late int _resendIn = widget.sent.resendIn.inSeconds;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  String t(String key) => AppTranslations.translate(context, ref, key);

  void _startCountdown() {
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
      final sent = await ref.read(passwordRepositoryProvider).sendCode();
      if (!mounted) return;
      setState(() {
        if (sent.maskedEmail.isNotEmpty) _masked = sent.maskedEmail;
        _resendIn = sent.resendIn.inSeconds;
      });
      _startCountdown();
      showAppToast(context, t('email_code_resent'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = emailAuthErrorText(context, ref, error));
      if (error is EmailAuthException && error.retryAfter != null) {
        setState(() => _resendIn = error.retryAfter!.inSeconds);
        _startCountdown();
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
    final length = _password.text.runes.length;
    if (length < 8 || length > 128) {
      setState(() => _error = t('password_too_short'));
      return;
    }
    if (_repeat.text != _password.text) {
      setState(() => _error = t('password_mismatch'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(passwordRepositoryProvider)
          .setPassword(code: code, password: _password.text);
      if (mounted) widget.onSaved();
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
            t('email_code_body').replaceAll('{email}', _masked),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 10),
            decoration: InputDecoration(
              labelText: t('email_code_field'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
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
          EmailAuthError(_error),
          EmailAuthButton(
            label: t('password_save'),
            busy: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _busy || _resendIn > 0 ? null : _resend,
              child: Text(
                _resendIn > 0
                    ? t(
                        'email_code_resend_in',
                      ).replaceAll('{seconds}', '$_resendIn')
                    : t('email_code_resend'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
