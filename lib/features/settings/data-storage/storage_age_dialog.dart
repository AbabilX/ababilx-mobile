import 'package:flutter/material.dart';

/// How far back "delete older media" reaches.
///
/// Three intervals rather than a date picker: the question being answered is
/// "keep roughly the recent stuff", and a calendar makes that a chore.
enum StorageAge {
  month('Older than 30 days', Duration(days: 30)),
  halfYear('Older than 6 months', Duration(days: 182)),
  year('Older than a year', Duration(days: 365));

  const StorageAge(this.label, this.age);

  final String label;
  final Duration age;

  DateTime cutoff() => DateTime.now().subtract(age);
}

Future<StorageAge?> showStorageAgeDialog(BuildContext context) =>
    showDialog<StorageAge>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Delete older media'),
        children: [
          for (final age in StorageAge.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(age),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(age.label),
              ),
            ),
        ],
      ),
    );
