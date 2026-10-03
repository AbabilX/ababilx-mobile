import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import 'phone_countries.dart';

/// Flag and calling code in front of the number; opens the country list.
class CountryCodeButton extends StatelessWidget {
  const CountryCodeButton({
    super.key,
    required this.country,
    required this.onTap,
  });

  final PhoneCountry country;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text('+${country.dial}', style: theme.textTheme.bodyLarge),
            const SizedBox(width: 2),
            ChatIcon(
              HugeIcons.strokeRoundedArrowDown01,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
