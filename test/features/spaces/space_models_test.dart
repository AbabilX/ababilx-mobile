import 'package:ababilx/features/spaces/data/space_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('space list parses and skips malformed rows', () {
    final list = SpaceSummary.listFromJson({
      'spaces': [
        {
          'id': 's1',
          'name': 'NetHex',
          'icon_url': 'https://x/i.png',
          'unread': true,
          'mentions': 3,
        },
        {'id': '', 'name': 'no id'},
        {'name': 'missing id'},
        'garbage',
        {'id': 's2', 'name': 'Panda'},
      ],
    });
    expect(list.map((s) => s.id), ['s1', 's2']);
    expect(list.first.mentions, 3);
    expect(list.first.unread, isTrue);
    expect(list.last.iconUrl, isEmpty);
    expect(list.last.mentions, 0);
  });

  test('a non-map body is an empty list, never a throw', () {
    expect(SpaceSummary.listFromJson(null), isEmpty);
    expect(SpaceSummary.listFromJson('x'), isEmpty);
    expect(SpaceSummary.listFromJson({'spaces': 'x'}), isEmpty);
  });

  test('channel tree parses categories, kinds and private flags', () {
    final tree = SpaceTree.fromJson('s1', {
      'space': {'id': 's1', 'name': 'NetHex'},
      'channels': [
        {'id': 'c0', 'name': 'general', 'kind': 'text'},
      ],
      'categories': [
        {
          'id': 'k1',
          'name': 'Admin & Management',
          'private': true,
          'channels': [
            {'id': 'c1', 'name': 'admin-chat', 'private': true, 'mentions': 2},
            {'id': 'c2', 'name': 'notify', 'kind': 'announcement'},
            {'id': 'c3', 'name': 'future', 'kind': 'voice'},
            {'id': '', 'name': 'bad'},
          ],
        },
        {'name': 'no id category'},
      ],
    });
    expect(tree.name, 'NetHex');
    expect(tree.channels.single.name, 'general');
    final cat = tree.categories.single;
    expect(cat.isPrivate, isTrue);
    expect(cat.channels.map((c) => c.id), ['c1', 'c2', 'c3']);
    expect(cat.channels[0].isPrivate, isTrue);
    expect(cat.channels[0].mentions, 2);
    expect(cat.channels[1].kind, SpaceChannelKind.announcement);
    // An unknown kind from a newer server reads as text, not a crash.
    expect(cat.channels[2].kind, SpaceChannelKind.text);
  });

  test('round trip through toJson keeps everything (the cache format)', () {
    final tree = SpaceTree.fromJson('s1', {
      'space': {'name': 'NetHex'},
      'channels': [
        {'id': 'c0', 'name': 'general', 'unread': true},
      ],
      'categories': [
        {
          'id': 'k1',
          'name': 'Devs',
          'channels': [
            {
              'id': 'c1',
              'name': 'backend',
              'private': true,
              'kind': 'announcement',
            },
          ],
        },
      ],
    });
    final again = SpaceTree.fromJson('s1', tree.toJson());
    expect(again.toJson(), tree.toJson());
    final list = [
      const SpaceSummary(
        id: 'a',
        name: 'A',
        iconUrl: 'u',
        unread: true,
        mentions: 1,
      ),
    ];
    expect(
      SpaceSummary.listFromJson(SpaceSummary.listToJson(list)).single.mentions,
      1,
    );
  });

  test('initials for icon-less spaces', () {
    expect(spaceInitials('Admin & Management'), 'AM');
    expect(spaceInitials('panda'), 'P');
    expect(spaceInitials('  '), '?');
    // Whole grapheme clusters: the vowel sign stays on its consonant.
    expect(spaceInitials('নেটহেক্স দল'), 'নেদ');
  });
}
