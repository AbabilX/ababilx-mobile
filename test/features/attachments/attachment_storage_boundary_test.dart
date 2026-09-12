import 'dart:io';

import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('private wipe never deletes exported AbabilXStorage files', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'ababilx-storage-boundary-',
    );
    addTearDown(() async {
      if (await sandbox.exists()) await sandbox.delete(recursive: true);
    });

    final privateRoot = Directory('${sandbox.path}/private');
    final publicRoot = Directory('${sandbox.path}/public/AbabilXStorage');
    await publicRoot.create(recursive: true);
    final exported = File('${publicRoot.path}/saved-photo.jpg');
    await exported.writeAsBytes([1, 2, 3]);

    final paths = AttachmentPaths(rootDirectory: () async => privateRoot);
    final downloaded = await paths.fileFor(
      'abcdef123456',
      'photo.jpg',
      'image/jpeg',
    );
    await downloaded.writeAsBytes([4, 5, 6]);

    await paths.deleteAll();

    expect(await downloaded.exists(), isFalse);
    expect(await exported.exists(), isTrue);
    expect(await exported.readAsBytes(), [1, 2, 3]);
  });
}
