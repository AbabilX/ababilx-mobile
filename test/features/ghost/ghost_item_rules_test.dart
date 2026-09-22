import 'package:ababilx/features/ghost/protocol/ghost_frames.dart';
import 'package:ababilx/features/ghost/protocol/ghost_item_rules.dart';
import 'package:flutter_test/flutter_test.dart';

GhostFileHeader _header(String raw) =>
    GhostFrame.decode(raw)! as GhostFileHeader;

void main() {
  group('GhostViewTimer', () {
    test('absent is off, known values map, unknown fails closed to once', () {
      expect(GhostViewTimer.decode(null), GhostViewTimer.off);
      expect(GhostViewTimer.decode('once'), GhostViewTimer.once);
      expect(GhostViewTimer.decode(5), GhostViewTimer.s5);
      expect(GhostViewTimer.decode(10), GhostViewTimer.s10);
      expect(GhostViewTimer.decode(30), GhostViewTimer.s30);
      for (final odd in [7, '5', 'forever', true, 0, -1]) {
        expect(GhostViewTimer.decode(odd), GhostViewTimer.once, reason: '$odd');
      }
    });
  });

  group('GhostItemRules', () {
    test('a timed photo can never be saved', () {
      const rules = GhostItemRules(timer: GhostViewTimer.s5, allowSave: true);
      expect(rules.allowSave, isFalse);
      expect(
        const GhostItemRules(
          allowSave: true,
        ).withTimer(GhostViewTimer.once).allowSave,
        isFalse,
      );
    });
  });

  group('file header rules', () {
    test('round-trip', () {
      const header = GhostFileHeader(
        id: 'f',
        name: 'a.jpg',
        mime: 'image/jpeg',
        size: 10,
        at: 1,
        rules: GhostItemRules(timer: GhostViewTimer.s10),
      );
      final back = _header(header.encode());
      expect(back.rules.timer, GhostViewTimer.s10);
      expect(back.rules.allowSave, isFalse);
      expect(back.encode(), header.encode());
    });

    test('an old header (no fields) means no timer, no saving', () {
      final back = _header(
        '{"t":"file","id":"f","name":"a.jpg","mime":"image/jpeg","size":3}',
      );
      expect(back.rules.timer, GhostViewTimer.off);
      expect(back.rules.allowSave, isFalse);
    });

    test('a timer on a document is dropped; save survives', () {
      final back = _header(
        '{"t":"file","id":"f","name":"a.pdf","mime":"application/pdf",'
        '"size":3,"view":5,"save":true}',
      );
      expect(back.rules.timer, GhostViewTimer.off);
      expect(back.rules.allowSave, isTrue);
    });

    test('a forged save beside a timer is refused', () {
      final back = _header(
        '{"t":"file","id":"f","name":"a.png","mime":"image/png",'
        '"size":3,"view":"once","save":true}',
      );
      expect(back.rules.timer, GhostViewTimer.once);
      expect(back.rules.allowSave, isFalse);
    });
  });

  group('viewed frame', () {
    test('round-trips and rejects a bad id', () {
      final frame = GhostFrame.decode(const GhostViewedFrame(id: 'x').encode());
      expect((frame! as GhostViewedFrame).id, 'x');
      expect(GhostFrame.decode('{"t":"viewed"}'), isNull);
      expect(GhostFrame.decode('{"t":"viewed","id":"${'x' * 65}"}'), isNull);
    });
  });
}
