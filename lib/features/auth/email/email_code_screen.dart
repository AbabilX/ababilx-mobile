import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import 'email_auth_actions.dart';
import 'email_auth_repository.dart';
import 'email_auth_ui.dart';
import 'email_code_args.dart';

/// Enter the emailed code: finishes a sign-up, or — with a new password —
/// a reset. Either way a correct code signs in.
class EmailCodeScreen extends ConsumerStatefulWidget {
  const EmailCodeScreen({super.key, required this.args});

  final EmailCodeArgs args;

  @override
  ConsumerState<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends ConsumerState<EmailCodeScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  late String _masked = widget.args.sent.maskedEmail;
  late int _resendIn = widget.args.sent.resendIn.inSeconds;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  bool get _reset => widget.args.purpose == EmailCodePurpose.reset;

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
      final sent = await widget.args.resend(
        ref.read(emailAuthRepositoryProvider),
      );
      if (!mounted) return;
      setState(() {
        _masked = sent.maskedEmail;
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
    if (_reset && (length < 8 || length > 128)) {
      setState(() => _error = t('password_too_short'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(emailAuthRepositoryProvider);
    final email = widget.args.email;
    try {
      final session = _reset
          ? await repo.confirmReset(
              email: email,
              code: code,
              password: _password.text,
            )
          : await repo.verifySignUp(email: email, code: code);
      if (!mounted) return;
      await adoptEmailSession(context, ref, session);
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
    return EmailAuthScaffold(
      title: _reset ? t('email_reset_title') : t('email_code_title'),
      subtitle: t('email_code_body').replaceAll('{email}', _masked),
      children: [
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
          onChanged: (value) {
            // A sign-up needs nothing else, so the sixth digit submits.
            if (!_reset && value.length == 6) _submit();
          },
        ),
        const SizedBox(height: 14),
        if (_reset)
          EmailAuthField(
            controller: _password,
            label: t('new_password_field'),
            helper: t('password_rule'),
            password: true,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
          ),
        EmailAuthError(_error),
        EmailAuthButton(
          label: _reset ? t('email_reset_save') : t('email_verify'),
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
    );
  }
}
