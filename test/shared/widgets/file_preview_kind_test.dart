import 'package:ababilx/shared/widgets/file_preview_kind.dart';
import 'package:ababilx/shared/widgets/image_preview_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies office types from name or mime', () {
    expect(FilePreviewKind.of(fileName: 'notes.docx'), FilePreviewKind.word);
    expect(
      FilePreviewKind.of(
        fileName: 'q1',
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      FilePreviewKind.sheet,
    );
    expect(FilePreviewKind.of(fileName: 'deck.pptx'), FilePreviewKind.slides);
    expect(FilePreviewKind.of(fileName: 'brief.pdf'), FilePreviewKind.pdf);
    expect(FilePreviewKind.of(fileName: 'dump.zip'), FilePreviewKind.zip);
  });

  test('formatPreviewFileSize hides a missing size', () {
    expect(formatPreviewFileSize(0), '');
    expect(formatPreviewFileSize(512), '512 B');
    expect(formatPreviewFileSize(2048), '2 KB');
  });

  testWidgets('document capsule dock shows Save, Open and Share', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImagePreviewDock(
            fileName: 'notes.docx',
            localPath: '/tmp/notes.docx',
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.byTooltip('Save'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.text('Rotate'), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });
}
