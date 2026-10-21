import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../profile/data/username_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../../settings/username/username_availability.dart';
import '../../settings/username/username_rules.dart';
import 'profile_setup_step.dart';
import 'random_profile.dart';

/// Step 2: the handle a personal QR code carries. Required here.
///
/// With no handle yet, the field opens on a random one drawn from the name
/// (`calm_falcon4821`). That draw is kept only after the server says it is
/// free; a taken one is replaced. Next stays off until the handle in the
/// field is free (or it is the one this account already holds). Skip draws
/// another and moves on only after that read and the save both succeed.
/// The save is still what claims it.
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
  UsernameAvailability _availability = UsernameAvailability.unknown;
  String? _checked;
  Timer? _debounce;
  int _lookup = 0;

  String get _stored => ref.read(profileProvider).valueOrNull?.username ?? '';

  bool get _ready => usernameReadyToSave(
    typed: _ctrl.text,
    stored: _stored,
    availability: _availability,
    checkedHandle: _checked,
  );

  @override
  void initState() {
    super.initState();
    if (_stored.isNotEmpty && isValidUsername(_stored)) {
      _ctrl = TextEditingController(text: _stored);
      _checked = _stored;
      _availability = UsernameAvailability.free;
      return;
    }
    final draft = RandomProfile.username(_nameForHandle());
    _ctrl = TextEditingController(text: draft);
    _availability = UsernameAvailability.checking;
    final token = ++_lookup;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_settleDraft(draft, token));
    });
  }

  String _nameForHandle() {
    final name = ref.read(profileProvider).valueOrNull?.name ?? '';
    return name.isEmpty ? RandomProfile.name() : name;
  }

  /// Keeps [draft] when it is free. A taken one is swapped for another free
  /// draw. Editing the field cancels this: [_onChanged] moves [_lookup].
  Future<void> _settleDraft(String draft, int token) async {
    final first = await _readFree(draft, token);
    if (!mounted || token != _lookup) return;
    if (normalizeUsername(_ctrl.text) != draft) return;
    if (first == true) {
      setState(() {
        _checked = draft;
        _availability = UsernameAvailability.free;
        _error = null;
      });
      return;
    }
    if (first == null) return;
    final handle = await _firstFree(token);
    if (!mounted || token != _lookup) return;
    if (normalizeUsername(_ctrl.text) != draft) return;
    if (handle == null) {
      setState(() {
        _checked = draft;
        _availability = UsernameAvailability.taken;
        _saving = false;
        _error ??= AppTranslations.of(
          ref.read(appLanguageProvider),
          'profile_setup_username_error',
        );
      });
      return;
    }
    _ctrl.text = handle;
    setState(() {
      _checked = handle;
      _availability = UsernameAvailability.free;
      _error = null;
    });
  }

  /// `true` free, `false` taken, null when the read failed (error already set).
  Future<bool?> _readFree(String handle, int token) async {
    try {
      return await ref.read(usernameRepositoryProvider).available(handle);
    } catch (_) {
      if (!mounted || token != _lookup) return null;
      setState(() {
        _checked = handle;
        _availability = UsernameAvailability.failed;
        _saving = false;
        _error = AppTranslations.of(
          ref.read(appLanguageProvider),
          'profile_setup_username_check_error',
        );
      });
      return null;
    }
  }

  /// The first random handle the server calls free, or null.
  Future<String?> _firstFree(int token) async {
    final base = _nameForHandle();
    for (var i = 0; i < 6; i++) {
      if (!mounted || token != _lookup) return null;
      final handle = RandomProfile.username(base);
      final free = await _readFree(handle, token);
      if (free == null) return null;
      if (free) return handle;
    }
    return null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _error = null;
    final handle = normalizeUsername(_ctrl.text);
    if (_stored.isNotEmpty && handle == _stored) {
      _debounce?.cancel();
      _lookup++;
      setState(() {
        _checked = handle;
        _availability = UsernameAvailability.free;
      });
      return;
    }
    if (!isValidUsername(handle)) {
      _debounce?.cancel();
      _lookup++;
      setState(() {
        _checked = null;
        _availability = UsernameAvailability.unknown;
      });
      return;
    }
    setState(() {
      _checked = null;
      _availability = UsernameAvailability.checking;
    });
    final token = ++_lookup;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_lookupHandle(handle, token));
    });
  }

  Future<void> _lookupHandle(String handle, int token) async {
    bool free;
    try {
      free = await ref.read(usernameRepositoryProvider).available(handle);
    } catch (_) {
      if (!mounted || token != _lookup) return;
      setState(() {
        _checked = handle;
        _availability = UsernameAvailability.failed;
        _error = AppTranslations.of(
          ref.read(appLanguageProvider),
          'profile_setup_username_check_error',
        );
      });
      return;
    }
    if (!mounted || token != _lookup) return;
    if (normalizeUsername(_ctrl.text) != handle) return;
    setState(() {
      _checked = handle;
      _availability = free
          ? UsernameAvailability.free
          : UsernameAvailability.taken;
    });
  }

  Future<void> _next() async {
    if (!_ready) return;
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
      if (error.reason == UsernameFailure.taken) {
        _availability = UsernameAvailability.taken;
        _checked = handle;
      }
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

  /// Skip: a random handle, kept only when the same read says it is free,
  /// then saved. A taken draw is dropped. An account that already has a
  /// handle keeps it and moves on.
  Future<void> _skip() async {
    if (_stored.isNotEmpty) return widget.onDone();
    _debounce?.cancel();
    final token = ++_lookup;
    setState(() {
      _saving = true;
      _error = null;
      _availability = UsernameAvailability.checking;
      _checked = null;
    });
    String? failure;
    for (var i = 0; i < 6; i++) {
      final handle = await _firstFree(token);
      if (!mounted || token != _lookup) return;
      if (handle == null) break;
      _ctrl.text = handle;
      _checked = handle;
      _availability = UsernameAvailability.free;
      try {
        await ref.read(profileProvider.notifier).updateUsername(handle);
        if (mounted) widget.onDone();
        return;
      } on UsernameException catch (error) {
        if (error.reason == UsernameFailure.taken) continue;
        failure = error.message;
        break;
      } catch (_) {
        failure = AppTranslations.of(
          ref.read(appLanguageProvider),
          'profile_setup_username_error',
        );
        break;
      }
    }
    if (!mounted || token != _lookup) return;
    if (_availability == UsernameAvailability.failed) {
      setState(() => _saving = false);
      return;
    }
    setState(() {
      _saving = false;
      _error =
          failure ??
          AppTranslations.of(
            ref.read(appLanguageProvider),
            'profile_setup_username_error',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final colors = Theme.of(context).colorScheme;
    final formatError = usernameError(_ctrl.text);
    final taken = _availability == UsernameAvailability.taken;
    final checking = _availability == UsernameAvailability.checking && !_saving;
    final free =
        _availability == UsernameAvailability.free &&
        _checked != null &&
        _checked != _stored;
    return ProfileSetupStep(
      step: 1,
      titleKey: 'profile_setup_username_title',
      bodyKey: 'profile_setup_username_body',
      busy: _saving,
      onNext: _ready ? _next : null,
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
        onChanged: _onChanged,
        onSubmitted: (_) => _ready ? _next() : null,
        decoration: InputDecoration(
          prefixText: '@',
          labelText: t('profile_setup_username_label'),
          border: const OutlineInputBorder(),
          errorText:
              formatError ??
              (taken ? t('profile_setup_username_taken') : _error),
          helperText: checking
              ? t('profile_setup_username_checking')
              : free
              ? t('profile_setup_username_available')
              : null,
          helperStyle: TextStyle(
            color: free ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
