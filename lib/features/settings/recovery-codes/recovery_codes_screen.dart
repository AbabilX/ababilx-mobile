import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../../messages/data/chat_recovery_api.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/message_e2ee/recovery_code_card.dart';
import '../../messages/message_e2ee/new_chat_setup.dart';
import '../../messages/message_e2ee/new_chat_setup_banner.dart';

/// No remembered verification state. Leaving this route destroys the reveal;
/// opening it again always creates a new, single-use email challenge.
class RecoveryCodesScreen extends ConsumerStatefulWidget {
  const RecoveryCodesScreen({super.key});
  @override
  ConsumerState<RecoveryCodesScreen> createState() => _State();
}

class _State extends ConsumerState<RecoveryCodesScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  String _challenge = '', _email = '', _code = '';
  String? _error;
  bool _busy = false, _legacy = false, _verifying = false;
  int _epoch = 0;
  DateTime? _resendAt;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _epoch++;
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Switching to the email app before submitting is allowed. A reveal (or
    // its in-flight response) must not survive leaving the foreground.
    if (state != AppLifecycleState.resumed &&
        (_code.isNotEmpty || _verifying)) {
      _hide();
    }
  }

  void _hide() {
    _epoch++;
    _hideTimer?.cancel();
    _input.clear();
    if (mounted) {
      setState(() {
        _code = '';
        _challenge = '';
        _busy = false;
        _verifying = false;
      });
    }
  }

  Future<void> _request() async {
    if (_busy) return;
    if (_resendAt?.isAfter(DateTime.now()) ?? false) {
      setState(() => _error = 'recovery_wait_resend');
      return;
    }
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _code = '';
    });
    try {
      final hasLocalCode = await ref
          .read(messageVaultProvider)
          .hasStoredRecoveryCode();
      final result = await ref.read(chatRecoveryApiProvider).challenge();
      if (!mounted || epoch != _epoch) return;
      _input.clear();
      setState(() {
        _challenge = result['challenge_id'] as String;
        _email = result['email'] as String;
        _legacy = !hasLocalCode;
        _resendAt = DateTime.now().add(
          Duration(seconds: (result['retry_after'] as num?)?.toInt() ?? 60),
        );
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = 'recovery_send_failed');
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _challenge.isEmpty) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _verifying = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(chatRecoveryApiProvider)
          .verify(_challenge, _input.text.trim());
      if (!mounted || epoch != _epoch) return;
      final vault = ref.read(messageVaultProvider);
      final public = result['public_key'];
      if (result['verified'] != true ||
          public is! Map ||
          public['x'] != vault.publicIdentity?['x'] ||
          public['y'] != vault.publicIdentity?['y']) {
        throw StateError('Message identity changed');
      }
      // Legacy accounts never stored their code. The button explicitly says
      // "create" before this operation; ordinary reveals never rotate it.
      final code = _legacy
          ? await vault.regenerateRecoveryCode()
          : await vault.readVerifiedRecoveryCode(result);
      if (!mounted || epoch != _epoch) return;
      _input.clear();
      setState(() {
        _code = code;
        _challenge = '';
      });
      _hideTimer = Timer(const Duration(seconds: 60), _hide);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = 'recovery_verify_failed');
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _busy = false;
          _verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!isCurrent && (_code.isNotEmpty || _verifying)) {
      scheduleMicrotask(_hide);
    }
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Scaffold(
      appBar: AppBar(title: Text(t('recovery_codes_title'))),
      body: ref.watch(newChatSetupProvider).pending
          ? const Align(
              alignment: Alignment.topCenter,
              child: NewChatSetupBanner(),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    Icons.key_rounded,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('recovery_codes_body'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (_code.isNotEmpty) ...[
                    RecoveryCodeCard(code: _code),
                    const SizedBox(height: 16),
                    Text(t('recovery_codes_hide_hint')),
                    TextButton(
                      onPressed: _hide,
                      child: Text(t('recovery_hide')),
                    ),
                  ] else if (_challenge.isEmpty)
                    FilledButton(
                      onPressed: _busy ? null : _request,
                      child: Text(
                        t(_busy ? 'recovery_sending' : 'recovery_send'),
                      ),
                    )
                  else ...[
                    Text(t('recovery_sent').replaceAll('{email}', _email)),
                    const SizedBox(height: 16),
                    if (_legacy) ...[
                      Text(t('recovery_legacy_create')),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _input,
                      enabled: !_busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 9,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: t('recovery_email_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: Text(
                        t(
                          _busy
                              ? 'recovery_verifying'
                              : _legacy
                              ? 'recovery_verify_create'
                              : 'recovery_verify_view',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _request,
                      child: Text(t('recovery_resend')),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      t(_error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
