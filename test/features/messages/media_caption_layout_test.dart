import 'package:ababilx/features/messages/chat-timeline/media_caption_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long caption wraps to the media width', (tester) async {
    const captionKey = Key('caption');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: UnconstrainedBox(
              alignment: Alignment.topLeft,
              constrainedAxis: Axis.vertical,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: MediaCaptionLayout(
                  media: const SizedBox(width: 150, height: 260),
                  caption: const Text(
                    'a caption much longer than the portrait picture above',
                    key: captionKey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MediaCaptionLayout)).width, 150);
    expect(tester.getSize(find.byKey(captionKey)).width, 150);
  });

  testWidgets('no drawable media: caption keeps its own width', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: Align(alignment: Alignment.topLeft, child: _Empty()),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MediaCaptionLayout)).width, 30);
  });
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => MediaCaptionLayout(
    media: const SizedBox.shrink(),
    caption: const SizedBox(width: 30, height: 10),
  );
}
