import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../profile/data/username_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../username/username_rules.dart';

/// Pick the handle other people scan or type to reach this account.
///
/// It is not the display name and not the GitHub login: it is unique, it is
/// lowercase, and it is the entire contents of the personal QR code. Clearing
/// it is allowed and takes the account off every code already shared, which is
/// the only way to undo showing one.
class EditUsernameScreen extends ConsumerStatefulWidget {
  const EditUsernameScreen({super.key});

  @override
  ConsumerState<EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends ConsumerState<EditUsernameScreen> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(profileProvider).valueOrNull?.username ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _stored => ref.read(profileProvider).valueOrNull?.username ?? '';

  bool get _canSave {
    if (_saving) return false;
    final next = normalizeUsername(_ctrl.text);
    if (next == _stored) return false;
    // An empty field clears the handle, which is a real save, not an invalid
    // one — but only when there is something to clear.
    return next.isEmpty ? _stored.isNotEmpty : isValidUsername(next);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileProvider.notifier)
          .updateUsername(normalizeUsername(_ctrl.text));
      if (mounted) popOrGoHome(context);
    } on UsernameException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      // The typed handle stays in the field: losing it to a flaky connection
      // is worse than the error line.
      if (mounted) {
        setState(() => _error = 'Could not save your username. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typed = normalizeUsername(_ctrl.text);

    return Scaffold(
      appBar: AppBar(
        leading: AppBarBackButton(
          onPressed: _saving ? null : () => popOrGoHome(context),
        ),
        title: const Text('Username'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            enabled: !_saving,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              // Uppercase is folded on save anyway; folding it while typing
              // stops the field from showing a handle nobody will ever see.
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toLowerCase()),
              ),
              LengthLimitingTextInputFormatter(usernameMaxLength + 1),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              prefixText: '@',
              labelText: 'Username',
              border: const OutlineInputBorder(),
              errorText: _error ?? usernameError(_ctrl.text),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            typed.isEmpty
                ? 'Without a username your QR code cannot be created, and '
                      'people can only find you by email or phone.'
                : 'People can scan your QR code or type @$typed to start a '
                      'chat with you. Letters, numbers, and . _ - only.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
