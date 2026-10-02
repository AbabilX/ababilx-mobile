import 'dart:typed_data';

import 'package:ababilx/features/messages/chat-list/camera_send_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The in-app camera records video; its bytes reached Image.memory and the
  // send bar drew "Exception: Invalid image data".
  testWidgets('a video never goes through the image decoder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CameraSendThumb(
            bytes: Uint8List.fromList(List.filled(64, 7)),
            isVideo: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undecodable photo bytes show a glyph, not an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CameraSendThumb(bytes: Uint8List.fromList(List.filled(64, 7))),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Exception'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
