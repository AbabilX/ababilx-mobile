import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/data/username_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settings/username/username_rules.dart';
import 'profile_setup_step.dart';
import 'random_profile.dart';

/// Step 2: the handle a personal QR code carries. Required here.
///
/// Whether a handle is free is the server's answer to the save, never a
/// lookup beforehand (see [UsernameRepository]). A handle the account
/// already holds is kept without a write — a change is allowed once every
/// three days, and re-saving the same one must not spend it.
class UsernameStep extends ConsumerStatefulWidget {
  const UsernameStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends ConsumerState<UsernameStep> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  String get _stored => ref.read(profileProvider).valueOrNull?.username ?? '';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _stored);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final handle = normalizeUsername(_ctrl.text);
    if (handle == _stored) return widget.onDone();
    setState(() {
      _saving = true;
      _error = null;
    });
    String? failure;
    try {
      await ref.read(profileProvider.notifier).updateUsername(handle);
    } on UsernameException catch (error) {
      failure = error.message;
    } catch (_) {
      failure = AppTranslations.of(
        ref.read(appLanguageProvider),
        'profile_setup_username_error',
      );
    }
    if (!mounted) return;
    if (failure == null) return widget.onDone();
    setState(() {
      _saving = false;
      _error = failure;
    });
  }

  /// Skip: a random handle from the name (`calm_falcon4821`), drawn again
  /// while the server says it is taken. Keeps one the account already has.
  Future<void> _skip() async {
    if (_stored.isNotEmpty) return widget.onDone();
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = ref.read(profileProvider).valueOrNull?.name ?? '';
    for (var i = 0; i < 6; i++) {
      final handle = RandomProfile.username(
        name.isEmpty ? RandomProfile.name() : name,
      );
      try {
        await ref.read(profileProvider.notifier).updateUsername(handle);
        if (mounted) widget.onDone();
        return;
      } on UsernameException catch (error) {
        if (error.reason != UsernameFailure.taken) break;
      } catch (_) {
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = AppTranslations.of(
        ref.read(appLanguageProvider),
        'profile_setup_username_error',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = isValidUsername(_ctrl.text);
    return ProfileSetupStep(
      step: 1,
      titleKey: 'profile_setup_username_title',
      bodyKey: 'profile_setup_username_body',
      busy: _saving,
      onNext: valid ? _next : null,
      onSkip: _skip,
      field: TextField(
        controller: _ctrl,
        autofocus: true,
        enabled: !_saving,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          TextInputFormatter.withFunction(
            (_, next) => next.copyWith(text: next.text.toLowerCase()),
          ),
          LengthLimitingTextInputFormatter(usernameMaxLength + 1),
        ],
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => valid ? _next() : null,
        decoration: InputDecoration(
          prefixText: '@',
          labelText: AppTranslations.translate(
            context,
            ref,
            'profile_setup_username_label',
          ),
          border: const OutlineInputBorder(),
          errorText: _error ?? usernameError(_ctrl.text),
        ),
      ),
    );
  }
}
