import 'package:flutter/material.dart';

import 'discovery_settings.dart';

/// The phone number people can find you by.
///
/// Country code required, and the field says so: numbers are stored in E.164,
/// so a bare local number matches nobody. Never verified — there is no OTP —
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
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.stored);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _value => _ctrl.text;

  bool get _canSave {
    if (_saving) return false;
    final normalized = normalizePhoneNumber(_value);
    return normalized != null && normalized != widget.stored;
  }

  Future<void> _save() async {
    final normalized = normalizePhoneNumber(_value);
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
      // On success show exactly what was stored — the server strips the
      // spaces and dashes the user typed, and the field should not keep
      // claiming otherwise. On failure the typed value stays editable rather
      // than snapping back to the old number.
      if (failure == null) _ctrl.text = normalized;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final malformed =
        _value.trim().isNotEmpty && normalizePhoneNumber(_value) == null;

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
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+8801712345678',
                    border: const OutlineInputBorder(),
                    errorText:
                        _error ??
                        (malformed
                            ? 'Include the country code, e.g. +880'
                            : null),
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
