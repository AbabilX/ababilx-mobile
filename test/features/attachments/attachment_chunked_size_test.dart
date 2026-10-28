import 'dart:io';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chunked-size-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final start = r.headers.value('range') == null ? 0 : 1;
      r.response.statusCode = start == 0 ? 200 : 206;
      r.response.headers.chunkedTransferEncoding = true;
      r.response.add([1, 2, 3].sublist(start));
      await r.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  Future<DownloadOutcome> fetch({int expected = 0, int? max}) =>
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()).fetch(
        remoteUrl: 'http://127.0.0.1:${server.port}/asset',
        target: File('${dir.path}/asset'),
        partFile: File('${dir.path}/asset.part'),
        expectedBytes: expected,
        maxBytes: max,
      );

  for (final expected in [2, 100]) {
    test('rejects chunked body with wrong expected size $expected', () async {
      await expectLater(
        fetch(expected: expected),
        throwsA(
          isA<AttachmentDownloadFailure>().having(
            (e) => e.code,
            'code',
            'size_mismatch',
          ),
        ),
      );
      expect(await File('${dir.path}/asset').exists(), isFalse);
      expect(await File('${dir.path}/asset.part').exists(), isFalse);
    });
  }
  test('enforces actual byte ceiling without size headers', () async {
    await expectLater(
      fetch(max: 2),
      throwsA(
        isA<AttachmentDownloadFailure>().having(
          (e) => e.code,
          'code',
          oversizeFailure.code,
        ),
      ),
    );
    expect(await File('${dir.path}/asset').exists(), isFalse);
    expect(await File('${dir.path}/asset.part').exists(), isFalse);
  });
  test('includes retained bytes in the resumed ceiling', () async {
    await File('${dir.path}/asset.part').writeAsBytes([1]);
    await expectLater(
      fetch(max: 2),
      throwsA(
        isA<AttachmentDownloadFailure>().having(
          (e) => e.code,
          'code',
          oversizeFailure.code,
        ),
      ),
    );
    expect(await File('${dir.path}/asset').exists(), isFalse);
  });
  test(
    'accepts exact expected size and an unknown size below ceiling',
    () async {
      expect((await fetch(expected: 3, max: 3)).bytes, 3);
      expect((await fetch(max: 3)).bytes, 3);
    },
  );
}
