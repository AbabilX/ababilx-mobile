import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The 6-digit emailed code, digits only, centred and spaced.
class AccountCodeField extends StatelessWidget {
  const AccountCodeField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    autofocus: true,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    textAlign: TextAlign.center,
    // Digits only, never Bangla text, so tracking is safe here.
    style: Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(letterSpacing: 10),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}
