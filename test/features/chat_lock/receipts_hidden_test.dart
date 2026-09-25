import 'package:ababilx/features/dm-settings/receipts/receipts_hidden_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the peer holds the switch only when it is dark and not ours', () {
    expect(ReceiptsHidden.none.peerHolds, isFalse);
    expect(const ReceiptsHidden(hidden: true, mine: true).peerHolds, isFalse);
    expect(const ReceiptsHidden(hidden: true, mine: false).peerHolds, isTrue);
  });

  test('chat.receipts_hidden becomes the live state for that chat', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final overrides = container.read(receiptsHiddenOverridesProvider.notifier);

    overrides.onEvent({
      'type': 'chat.receipts_hidden',
      'conversation_id': 'c1',
      'receipts_hidden': {'hidden': true, 'mine': false},
    });
    final c1 = container.read(receiptsHiddenOverridesProvider)['c1']!;
    expect(c1.hidden, isTrue);
    expect(c1.mine, isFalse);

    // Malformed frames change nothing.
    overrides.onEvent({'conversation_id': 'c2'});
    overrides.onEvent({
      'conversation_id': 'c2',
      'receipts_hidden': {'hidden': 'yes'},
    });
    overrides.onEvent({
      'conversation_id': '',
      'receipts_hidden': {'hidden': true, 'mine': true},
    });
    expect(container.read(receiptsHiddenOverridesProvider).keys, ['c1']);
  });
}
