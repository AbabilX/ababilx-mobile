import 'package:ababilx/features/ghost/protocol/ghost_cluster.dart';
import 'package:ababilx/features/ghost/providers/ghost_state.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:flutter_test/flutter_test.dart';

GhostItem text(String id, {required bool fromMe, int minute = 0}) => GhostItem(
  id: id,
  fromMe: fromMe,
  at: DateTime(2026, 9, 17, 10, minute),
  body: 'hi',
);

GhostItem file(String id, {required bool fromMe, int minute = 0}) => GhostItem(
  id: id,
  fromMe: fromMe,
  at: DateTime(2026, 9, 17, 10, minute),
  fileName: 'a.jpg',
  mime: 'image/jpeg',
  size: 10,
);

void main() {
  test('a run of one sender collapses its facing corners', () {
    final a = text('1', fromMe: true);
    final b = text('2', fromMe: true);
    final c = text('3', fromMe: true);
    expect(ghostClusterPosition(null, a, b), MessageClusterPosition.start);
    expect(ghostClusterPosition(a, b, c), MessageClusterPosition.middle);
    expect(ghostClusterPosition(b, c, null), MessageClusterPosition.end);
  });

  test('the other person breaks a run', () {
    final mine = text('1', fromMe: true);
    final theirs = text('2', fromMe: false);
    expect(
      ghostClusterPosition(null, mine, theirs),
      MessageClusterPosition.single,
    );
    expect(
      ghostClusterPosition(mine, theirs, null),
      MessageClusterPosition.single,
    );
  });

  test('a new minute breaks a run, as it does in the timeline', () {
    final first = text('1', fromMe: true);
    final later = text('2', fromMe: true, minute: 1);
    expect(
      ghostClusterPosition(null, first, later),
      MessageClusterPosition.single,
    );
  });

  test('a file never clusters — a tile is not a line of text', () {
    final before = text('1', fromMe: true);
    final photo = file('2', fromMe: true);
    final after = text('3', fromMe: true);
    expect(
      ghostClusterPosition(before, photo, after),
      MessageClusterPosition.single,
    );
    expect(
      ghostClusterPosition(null, before, photo),
      MessageClusterPosition.single,
    );
  });
}
