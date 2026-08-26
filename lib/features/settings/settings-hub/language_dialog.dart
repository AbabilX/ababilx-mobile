import 'package:flutter/material.dart';

/// Language picker, extracted so both Settings and Profile can open the same
/// sheet instead of each growing its own copy of the dialog.
Future<String?> showLanguageDialog(BuildContext context, String current) {
  final colors = Theme.of(context).colorScheme;
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App language',
              style: Theme.of(dialogCtx).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            for (final option in const [
              ('en', 'English (EN)'),
              ('bn', 'বাংলা (BN)'),
            ])
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  option.$2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: current.toLowerCase() == option.$1
                    ? Icon(Icons.check_circle_rounded, color: colors.primary)
                    : null,
                onTap: () => Navigator.pop(dialogCtx, option.$1),
              ),
          ],
        ),
      ),
    ),
  );
}

String languageLabel(String code) =>
    code.toUpperCase() == 'BN' ? 'বাংলা (BN)' : 'English (EN)';
