import 'package:ababilx/features/local-backup/data/backup_file_name.dart';
import 'package:ababilx/features/local-backup/data/local_backup_settings.dart';
import 'package:ababilx/features/local-backup/ui/local_backup_name_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final at = DateTime(2026, 9, 27, 17, 1, 38);
  const stamp = '2026-09-27_17-01-38.abxbackup';

  test('the chosen name replaces the app and handle; the moment stays', () {
    expect(
      backupFileName('murad', at, customName: 'My chats'),
      'My chats-$stamp',
    );
    expect(
      backupFileName('murad', at, customName: 'আমার চ্যাট'),
      'আমার চ্যাট-$stamp',
    );
  });

  test('no name, or nothing usable, leaves the automatic name', () {
    const automatic = 'AbabilX-murad-$stamp';
    expect(backupFileName('murad', at), automatic);
    for (final name in ['', '   ', '../', '...', '///', '\u202E\u200B']) {
      expect(
        backupFileName('murad', at, customName: name),
        automatic,
        reason: name,
      );
    }
  });

  test('a name can never leave the folder or disguise the file', () {
    expect(cleanBackupName('../../etc/passwd'), 'etcpasswd');
    expect(cleanBackupName(r'..\..\secret'), 'secret');
    expect(cleanBackupName('.hidden'), 'hidden');
    expect(cleanBackupName('a\u0000b\nc'), 'abc');
    expect(cleanBackupName('photo\u202Egpj.exe'), 'photogpj.exe');
    expect(cleanBackupName('a:b*c?d"e<f>g|h'), 'abcdefgh');
    expect(cleanBackupName('  two   spaces  '), 'two spaces');
    final name = backupFileName('m', at, customName: '../x/../y');
    expect(name.contains('/'), isFalse);
    expect(name.endsWith('.abxbackup'), isTrue);
  });

  test('a long name is cut, and stays within what a folder allows', () {
    final cut = cleanBackupName('ব' * 500);
    expect(cut.runes.length, backupNameMaxLength);
    expect(
      backupFileName('m', at, customName: '\u{1F600}' * 500).length,
      lessThan(255),
    );
  });

  test('two backups under one name do not take each other\'s file', () {
    final later = at.add(const Duration(seconds: 1));
    expect(
      backupFileName('m', at, customName: 'x'),
      isNot(backupFileName('m', later, customName: 'x')),
    );
  });

  test('the name is kept per account, and cleaned on the way in', () async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalBackupSettingsStore();
    await store.write('a', const LocalBackupSettings(fileName: 'Mine'));
    expect((await store.read('a')).fileName, 'Mine');
    expect((await store.read('b')).fileName, '');
    expect(LocalBackupSettings.fromJson({'file_name': '../x'}).fileName, 'x');
    expect(LocalBackupSettings.fromJson({'file_name': 7}).fileName, '');
    const named = LocalBackupSettings(fileName: 'Mine');
    expect(named.copyWith(enabled: true).fileName, 'Mine');
    expect(named.copyWith(fileName: '').fileName, '');
  });

  testWidgets('the sheet previews the file and returns the cleaned name', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showBackupNameSheet(
                context,
                current: '',
                title: 'Backup file name',
                hint: 'Date and time are added',
                placeholder: 'AbabilX-murad',
                saveLabel: 'Save',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.enterText(find.byType(TextField), '  ../My chats ');
    await tester.pump();
    expect(find.textContaining('My chats-'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(picked, 'My chats');
  });
}
