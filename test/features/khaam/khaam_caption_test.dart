import 'package:ababilx/features/khaam/data/khaam_covers.dart';
import 'package:ababilx/features/khaam/data/khaam_payload.dart';
import 'package:ababilx/features/khaam/providers/khaam_compose_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every ready-made message fits the flap', () {
    for (final cover in khaamCovers) {
      for (final lang in ['bn', 'en']) {
        for (final m in cover.messagesFor(lang)) {
          expect(
            m.length,
            lessThanOrEqualTo(khaamCaptionMaxChars),
            reason: '${cover.id}/$lang: $m',
          );
        }
      }
    }
  });

  test('what goes out is never longer than the cap', () {
    final draft = KhaamComposeState(
      khaamId: 'k',
      cover: khaamCovers.first,
      message: 'x' * 80,
    );
    expect(draft.outgoingMessage.length, khaamCaptionMaxChars);
  });
}
