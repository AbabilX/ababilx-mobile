import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/root_back.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/email/email_auth_actions.dart';
import '../../auth/email/email_auth_repository.dart';
import '../../auth/email/email_auth_ui.dart';
import '../../messages/chat_icon.dart';
import 'password_code_form.dart';
import 'password_repository.dart';

final passwordStatusProvider = FutureProvider.autoDispose<PasswordStatus>(
  (ref) => ref.watch(passwordRepositoryProvider).status(),
);

/// Settings → Password: an account made with Google gets its first password
/// here, anyone else changes theirs. A code goes to the account's own inbox
/// first, then the code + new password are sent together. The web twin is
/// `Ababil-X-frontend` `components/settings/password-section/`.
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  EmailCodeSent? _sent;
  bool _sending = false;
  String? _error;

  String t(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _sendCode() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await ref.read(passwordRepositoryProvider).sendCode();
      if (mounted) setState(() => _sent = sent);
    } catch (error) {
      if (mounted) {
        setState(() => _error = emailAuthErrorText(context, ref, error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _saved(bool hadPassword) {
    showAppToast(
      context,
      t(hadPassword ? 'password_changed' : 'password_set_done'),
    );
    ref.invalidate(passwordStatusProvider);
    popOrGoHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(passwordStatusProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_password')),
      ),
      body: SafeArea(
        top: false,
        child: status.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadFailed(
            message: emailAuthErrorText(context, ref, error),
            retry: () => ref.invalidate(passwordStatusProvider),
            retryLabel: t('password_retry'),
          ),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _StatusLine(
                title: t(
                  s.hasPassword ? 'password_is_set' : 'password_not_set',
                ),
                body: t(
                  s.hasPassword ? 'password_set_body' : 'password_none_body',
                ),
                email: s.email,
              ),
              const SizedBox(height: 24),
              if (!s.canSet)
                EmailAuthError(t('password_cannot_set'))
              else if (_sent == null) ...[
                EmailAuthError(_error),
                EmailAuthButton(
                  label: t(s.hasPassword ? 'password_change' : 'password_add'),
                  busy: _sending,
                  onPressed: _sendCode,
                ),
              ] else
                PasswordCodeForm(
                  sent: _sent!,
                  onSaved: () => _saved(s.hasPassword),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.title,
    required this.body,
    required this.email,
  });

  final String title;
  final String body;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ChatIcon(
            HugeIcons.strokeRoundedSquareLock02,
            size: 22,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                email.isEmpty ? body : '$body\n$email',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({
    required this.message,
    required this.retry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback retry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: retry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}
