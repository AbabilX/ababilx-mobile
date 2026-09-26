import 'dart:math' as math;

import 'package:ababilx/features/khaam/data/khaam_payload.dart';
import 'package:ababilx/features/khaam/data/khaam_photo_compress.dart';
import 'package:ababilx/features/messages/data/models/chat_media_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('the photo name rides in the card and round-trips', () {
    final name = khaamPhotoFileName('k1');
    final body = encodeKhaamBody(
      KhaamPayload(id: 'k1', coverId: 'eid', message: 'hi', photo: name),
    );
    expect(KhaamPayload.tryParse(body)!.photo, 'khaam-k1.jpg');
    expect(isKhaamPhotoFile(name), isTrue);
  });

  test('a card without a photo carries no photo key', () {
    final body = encodeKhaamBody(
      const KhaamPayload(id: 'k2', coverId: 'eid', message: 'hi'),
    );
    expect(body, isNot(contains('photo')));
    expect(KhaamPayload.tryParse(body)!.photo, isNull);
  });

  test('shared media leaves a Khaam photo out', () {
    Map<String, dynamic> item(String name) => {
      'id': name,
      'file_url': 'https://cdn/x/$name',
      'file_name': name,
      'content_type': 'image/jpeg',
      'size_bytes': 10,
    };
    final page = ChatMediaPage.fromJson({
      'items': [item('khaam-k1.jpg'), item('beach.jpg')],
    });
    expect(page.items.map((a) => a.fileName), ['beach.jpg']);
  });

  test('a heavy photo is squeezed under the budget', () async {
    final rnd = math.Random(1);
    final noisy = img.Image(width: 1280, height: 960);
    for (final p in noisy) {
      p.setRgb(rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
    }
    final heavy = img.encodeJpg(noisy, quality: 95);
    expect(heavy.length, greaterThan(khaamPhotoMaxBytes));
    final out = await compressKhaamPhoto(heavy);
    expect(out.length, lessThanOrEqualTo(khaamPhotoMaxBytes));
    expect(img.decodeJpg(out), isNotNull);
  });

  test('a photo already small enough is left alone', () async {
    final small = img.encodeJpg(img.Image(width: 400, height: 300));
    expect(identical(await compressKhaamPhoto(small), small), isTrue);
  });
}
