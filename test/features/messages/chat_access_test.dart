import 'package:ababilx/features/messages/providers/chat_access_provider.dart';
import 'package:ababilx/features/messages/providers/team_gate_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

bool canChat({required bool hasTeam, required bool independent}) {
  final container = ProviderContainer(
    overrides: [
      hasTeamProvider.overrideWithValue(hasTeam),
      independentChatProvider.overrideWithValue(independent),
    ],
  );
  addTearDown(container.dispose);
  return container.read(chatEnabledProvider);
}

void main() {
  group('chat availability', () {
    test('a workspace member can chat', () {
      expect(canChat(hasTeam: true, independent: false), isTrue);
    });

    test('independent chat alone is enough — no workspace needed', () {
      expect(canChat(hasTeam: false, independent: true), isTrue);
    });

    test('both on is still on', () {
      expect(canChat(hasTeam: true, independent: true), isTrue);
    });

    test('neither means chat really is unavailable', () {
      expect(canChat(hasTeam: false, independent: false), isFalse);
    });
  });
}
