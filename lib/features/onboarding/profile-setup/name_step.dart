import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settings/display-name/display_name_rules.dart';
import 'profile_setup_step.dart';
import 'random_profile.dart';

/// Step 1: the name everyone else sees. Prefilled with what Google or the
/// email sign-up form already gave; unchanged, Next writes nothing.
class NameStep extends ConsumerStatefulWidget {
  const NameStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _error;

  String get _stored => ref.read(profileProvider).valueOrNull?.name ?? '';

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
    final name = normalizeDisplayName(_ctrl.text);
    if (name == _stored) return widget.onDone();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).updateName(name);
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppTranslations.of(
            ref.read(appLanguageProvider),
            'profile_setup_name_error',
          );
        });
      }
    }
  }

  /// Skip: a random two-word name, unless one is already there.
  Future<void> _skip() async {
    if (_stored.isNotEmpty) return widget.onDone();
    _ctrl.text = RandomProfile.name();
    await _next();
  }

  @override
  Widget build(BuildContext context) {
    final left = displayNameRunesLeft(_ctrl.text);
    final valid = isValidDisplayName(_ctrl.text);
    return ProfileSetupStep(
      step: 0,
      titleKey: 'profile_setup_name_title',
      bodyKey: 'profile_setup_name_body',
      busy: _saving,
      onNext: valid ? _next : null,
      onSkip: _skip,
      field: TextField(
        controller: _ctrl,
        autofocus: true,
        enabled: !_saving,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => valid ? _next() : null,
        decoration: InputDecoration(
          labelText: AppTranslations.translate(
            context,
            ref,
            'profile_setup_name_label',
          ),
          border: const OutlineInputBorder(),
          errorText: _error,
          counterText: left <= 10 ? '$left' : '',
        ),
      ),
    );
  }
}
