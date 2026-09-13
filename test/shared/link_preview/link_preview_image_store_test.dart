import 'dart:typed_data';

import 'package:ababilx/shared/link-preview/link_preview_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real 3x2 PNG. The card's layout turns on which of the two numbers is
/// bigger (`isBigImagePreview`), so a swapped pair would silently give every
/// landscape picture the small thumbnail treatment.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 3, 0, 0, 0, 2, 8, 2, 0, 0, 0, 18, 22, 241, 77,
  0, 0, 0, 16, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 0, 65,
  12, 112, 22, 0, 65, 210, 5, 251, 135, 240, 185, 72,
  0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('measurePreviewImage reads width then height off the header', () async {
    final size = await measurePreviewImage(_png);
    expect(size, isNotNull);
    expect(size!.width, 3);
    expect(size.height, 2);
  });

  test('measurePreviewImage refuses bytes that are not an image', () async {
    // The decode is the last check that a picture is a picture: the content
    // type was a claim by the same host that wrote the link.
    expect(
      await measurePreviewImage(Uint8List.fromList('<html>'.codeUnits)),
      isNull,
    );
    expect(await measurePreviewImage(Uint8List(0)), isNull);
  });
}
