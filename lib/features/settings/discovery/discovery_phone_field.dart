import 'package:flutter/material.dart';

import 'country_code_button.dart';
import 'country_picker_sheet.dart';
import 'phone_compose.dart';
import 'phone_countries.dart';

/// The phone number people can find you by.
///
/// Numbers are stored in E.164, so a bare local number matches nobody: the
/// country is picked in front of the field and its code is added on save.
/// Never verified — there is no OTP —
/// so it is discovery only, never sign-in and never account recovery.
class DiscoveryPhoneField extends StatefulWidget {
  const DiscoveryPhoneField({
    super.key,
    required this.stored,
    required this.onSave,
  });

  final String stored;

  /// Returns null on success, or a sentence to show under the field.
  final Future<String?> Function(String phoneNumber) onSave;

  @override
  State<DiscoveryPhoneField> createState() => _DiscoveryPhoneFieldState();
}

class _DiscoveryPhoneFieldState extends State<DiscoveryPhoneField> {
  late final TextEditingController _ctrl;
  late PhoneCountry _country;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _country = phoneCountryOfNumber(widget.stored) ?? phoneCountryByIso('BD')!;
    _ctrl = TextEditingController(
      text: nationalPartOf(widget.stored, _country),
    );
  }

  /// A full number pasted with its own "+code" picks the country itself.
  void _onChanged(String value) {
    final pasted = value.trim();
    final country = phoneCountryOfNumber(pasted.replaceAll(' ', ''));
    if (country == null) {
      // The 0 dialled inside one's own country is not part of the number.
      if (_country.iso != 'IT' && pasted.startsWith('0')) {
        final cut = pasted.replaceFirst(RegExp(r'^0+'), '');
        _ctrl.value = TextEditingValue(
          text: cut,
          selection: TextSelection.collapsed(offset: cut.length),
        );
      }
      return setState(() {});
    }
    final rest = nationalPartOf(
      '+${pasted.replaceAll(RegExp(r'[^0-9]'), '')}',
      country,
    );
    setState(() => _country = country);
    _ctrl.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(offset: rest.length),
    );
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(context, selected: _country);
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      _error = null;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _value => _ctrl.text;

  String? get _composed => composePhoneNumber(_country, _value);

  bool get _canSave {
    if (_saving) return false;
    final normalized = _composed;
    return normalized != null && normalized != widget.stored;
  }

  Future<void> _save() async {
    final normalized = _composed;
    if (normalized == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await widget.onSave(normalized);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = failure;
      // On success show exactly what was stored — the spaces, dashes and
      // leading 0 the user typed are gone, and the field should not keep
      // claiming otherwise. On failure the typed value stays editable rather
      // than snapping back to the old number.
      if (failure == null) _ctrl.text = nationalPartOf(normalized, _country);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final malformed = _value.trim().isNotEmpty && _composed == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '1712345678',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: const OutlineInputBorder(),
                    prefixIcon: CountryCodeButton(
                      country: _country,
                      onTap: _saving ? null : _pickCountry,
                    ),
                    errorText:
                        _error ??
                        (malformed ? 'Enter a valid phone number' : null),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Used only so people who already have your number can find you. '
            'It is never shown on your profile, and never used to sign in.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
