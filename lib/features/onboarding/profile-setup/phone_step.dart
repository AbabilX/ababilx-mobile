import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../settings/discovery/country_code_button.dart';
import '../../settings/discovery/country_picker_sheet.dart';
import '../../settings/discovery/discovery_provider.dart';
import '../../settings/discovery/phone_compose.dart';
import '../../settings/discovery/phone_countries.dart';
import 'profile_setup_step.dart';

/// Step 3: the number people who already have it can find this account by.
/// Never verified, discovery only — so it can be skipped, and Settings →
/// Discovery takes it later.
class PhoneStep extends ConsumerStatefulWidget {
  const PhoneStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<PhoneStep> {
  final _ctrl = TextEditingController();
  PhoneCountry _country = phoneCountryByIso('BD')!;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? get _composed => composePhoneNumber(_country, _ctrl.text);

  /// Same typing rules as Settings → Discovery: a pasted "+code" picks the
  /// country, and the 0 dialled inside one's own country is dropped.
  void _onChanged(String value) {
    final pasted = value.trim();
    final country = phoneCountryOfNumber(pasted.replaceAll(' ', ''));
    var text = pasted;
    if (country != null) {
      _country = country;
      text = nationalPartOf(
        '+${pasted.replaceAll(RegExp(r'[^0-9]'), '')}',
        country,
      );
    } else if (_country.iso != 'IT' && pasted.startsWith('0')) {
      text = pasted.replaceFirst(RegExp(r'^0+'), '');
    }
    if (text != value) {
      _ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    setState(() => _error = null);
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(context, selected: _country);
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      _error = null;
    });
  }

  Future<void> _save() async {
    final number = _composed;
    if (number == null || number.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await ref
        .read(discoveryProvider.notifier)
        .savePhone(number);
    if (!mounted) return;
    if (failure == null) return widget.onDone();
    setState(() {
      _saving = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final composed = _composed;
    final malformed = _ctrl.text.trim().isNotEmpty && composed == null;
    final ready = composed != null && composed.isNotEmpty;
    return ProfileSetupStep(
      step: 2,
      titleKey: 'profile_setup_phone_title',
      bodyKey: 'profile_setup_phone_body',
      busy: _saving,
      onNext: ready ? _save : null,
      onSkip: widget.onDone,
      field: TextField(
        controller: _ctrl,
        autofocus: true,
        enabled: !_saving,
        keyboardType: TextInputType.phone,
        onChanged: _onChanged,
        onSubmitted: (_) => ready ? _save() : null,
        decoration: InputDecoration(
          labelText: t('profile_setup_phone_label'),
          hintText: '1712345678',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          prefixIcon: CountryCodeButton(
            country: _country,
            onTap: _saving ? null : _pickCountry,
          ),
          errorText:
              _error ?? (malformed ? t('profile_setup_phone_invalid') : null),
        ),
      ),
    );
  }
}
