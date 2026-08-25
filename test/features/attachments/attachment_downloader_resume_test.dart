import 'dart:io';

import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late HttpServer server;
  late List<int> bytes;
  final ranges = <String?>[];
  var rejectCount = 0;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ababilx-attachment-test-');
    bytes = List<int>.generate(4096, (index) => index % 251);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final path = request.uri.path;
      if (path == '/reject' && range != null && rejectCount++ == 0) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await request.response.close();
        return;
      }
      if (path == '/stall') {
        // Headers, then silence — stands in for a transfer the user cancels
        // before it finishes.
        request.response.contentLength = bytes.length;
        await request.response.flush();
        return;
      }
      if (path == '/ignore' || range == null) {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
        return;
      }
      final start = int.parse(range.split('=').last.split('-').first);
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${bytes.length - 1}/${bytes.length}',
      );
      request.response.contentLength = bytes.length - start;
      request.response.add(bytes.sublist(start));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await temp.delete(recursive: true);
    ranges.clear();
    rejectCount = 0;
  });

  String url(String path) =>
      'http://${server.address.host}:${server.port}$path';

  AttachmentDownloader downloader() =>
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher());

  test('resumes a part file with one Range request', () async {
    final target = File('${temp.path}/asset.bin');
    final part = File('${target.path}.part');
    await part.writeAsBytes(bytes.sublist(0, 1000));

    final result = await downloader().fetch(
      remoteUrl: url('/range'),
      target: target,
      partFile: part,
      expectedBytes: bytes.length,
    );

    expect(ranges, ['bytes=1000-']);
    expect(await result.file.readAsBytes(), bytes);
    expect(await part.exists(), isFalse);
  });

  test('truncates when the server ignores Range', () async {
    final target = File('${temp.path}/ignored.bin');
    final part = File('${target.path}.part');
    await part.writeAsBytes(bytes.sublist(0, 700));

    final result = await downloader().fetch(
      remoteUrl: url('/ignore'),
      target: target,
      partFile: part,
      expectedBytes: bytes.length,
    );

    expect(ranges.single, 'bytes=700-');
    expect(await result.file.readAsBytes(), bytes);
  });

  test('416 drops the stale part and retries once from zero', () async {
    final target = File('${temp.path}/rejected.bin');
    final part = File('${target.path}.part');
    await part.writeAsBytes(bytes.sublist(0, 900));

    final result = await downloader().fetch(
      remoteUrl: url('/reject'),
      target: target,
      partFile: part,
      expectedBytes: bytes.length,
    );

    expect(ranges, ['bytes=900-', null]);
    expect(await result.file.readAsBytes(), bytes);
  });

  test('size mismatch is permanent and writes no bytes', () async {
    final target = File('${temp.path}/mismatch.bin');
    final part = File('${target.path}.part');

    await expectLater(
      downloader().fetch(
        remoteUrl: url('/range'),
        target: target,
        partFile: part,
        expectedBytes: bytes.length + 1,
      ),
      throwsA(
        isA<AttachmentDownloadFailure>()
            .having((error) => error.code, 'code', 'size_mismatch')
            .having((error) => error.permanent, 'permanent', isTrue),
      ),
    );
    expect(await target.exists(), isFalse);
    expect(await part.exists(), isFalse);
  });

  test('cancelling never discards already-transferred bytes', () async {
    final target = File('${temp.path}/cancelled.bin');
    final part = File('${target.path}.part');
    // Stands in for a transfer that got this far before the user tapped stop.
    await part.writeAsBytes(bytes.sublist(0, 1000));
    final token = CancelToken();

    final inFlight = downloader().fetch(
      remoteUrl: url('/stall'),
      target: target,
      partFile: part,
      expectedBytes: bytes.length,
      cancelToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    token.cancel('user tapped stop');

    await expectLater(inFlight, throwsA(isA<DioException>()));
    // The sticky part file is the whole point: a cancel must cost nothing
    // already transferred, and must never leave a finished-looking target.
    expect(await part.exists(), isTrue);
    expect(await part.length(), 1000);
    expect(await target.exists(), isFalse);

    ranges.clear();
    final resumed = await downloader().fetch(
      remoteUrl: url('/range'),
      target: target,
      partFile: part,
      expectedBytes: bytes.length,
    );
    expect(ranges, ['bytes=1000-'], reason: 'the retry resumes, not restarts');
    expect(await resumed.file.readAsBytes(), bytes);
  });

  test('a cancelled transfer is not counted as a failure', () {
    final cancelled = DioException.requestCancelled(
      requestOptions: RequestOptions(path: '/stall'),
      reason: 'user tapped stop',
    );
    expect(isCancellation(cancelled), isTrue);
    expect(classifyDownloadError(cancelled).code, 'cancelled');
  });
}
