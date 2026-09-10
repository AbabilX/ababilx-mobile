import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/message_e2ee/recovery_code_card.dart';

class RecoveryCodesScreen extends ConsumerStatefulWidget {
  const RecoveryCodesScreen({super.key});
  @override
  ConsumerState<RecoveryCodesScreen> createState() => _State();
}

class _State extends ConsumerState<RecoveryCodesScreen>
    with WidgetsBindingObserver {
  String? _code, _error;
  bool _busy = false, _missing = false;
  int _epoch = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _epoch++;
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide();
  }

  void _hide() {
    _epoch++;
    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _code = null;
        _busy = false;
      });
    }
  }

  Future<void> _load({bool create = false}) async {
    if (_busy) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vault = ref.read(messageVaultProvider);
      // Opening settings never rotates a code. Legacy users explicitly create
      // one only when this phone has no saved code.
      final code = create
          ? await vault.regenerateRecoveryCode()
          : await vault.readStoredRecoveryCode();
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _code = code;
        _missing = code == null;
      });
      _hideTimer?.cancel();
      if (code != null) _hideTimer = Timer(const Duration(seconds: 60), _hide);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = 'recovery_code_load_failed');
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!isCurrent && (_code != null || _busy)) scheduleMicrotask(_hide);
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Scaffold(
      appBar: AppBar(title: Text(t('recovery_codes_title'))),
      body: SafeArea(
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
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else if (_code != null) ...[
              RecoveryCodeCard(code: _code!),
              const SizedBox(height: 16),
              Text(t('recovery_codes_hide_hint')),
              TextButton(onPressed: _hide, child: Text(t('recovery_hide'))),
            ] else ...[
              if (_missing) ...[
                Text(t('recovery_legacy_create')),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: () => _load(create: _missing),
                child: Text(t(_missing ? 'recovery_create' : 'recovery_view')),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                t(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
