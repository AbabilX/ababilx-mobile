import 'package:ababilx/features/messages/chat-list/add_friends_reveal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a pulled-open row is only held for five seconds', () {
    expect(addFriendsRevealHold, const Duration(seconds: 5));
  });

  test('five chats or fewer keep Add new friends on screen', () {
    expect(addFriendsHeaderCollapses(0), isFalse);
    expect(addFriendsHeaderCollapses(5), isFalse);
    expect(addFriendsHeaderCollapses(6), isTrue);
  });

  test('a short pull opens the row and a further pull refreshes once', () {
    final gate = AddFriendsPullGate();
    expect(gate.dragged(40, refreshDistance: 100), isFalse);
    expect(gate.open, isFalse);
    expect(gate.reveal, closeTo(40 / 72, 0.001));

    expect(gate.dragged(32, refreshDistance: 100), isFalse);
    expect(gate.open, isTrue);
    expect(gate.reveal, 1);

    expect(gate.dragged(99, refreshDistance: 100), isFalse);
    expect(gate.dragged(1, refreshDistance: 100), isTrue);
    expect(gate.dragged(40, refreshDistance: 100), isFalse);
  });

  test('letting go before the row locks tucks it away', () {
    final gate = AddFriendsPullGate();
    gate.dragged(20, refreshDistance: 100);
    gate.released();
    expect(gate.open, isFalse);
    expect(gate.reveal, 0);
  });

  test('a row that locked open stays after the finger lifts', () {
    final gate = AddFriendsPullGate();
    gate.dragged(72, refreshDistance: 100);
    gate.released();
    expect(gate.open, isTrue);
    expect(gate.reveal, 1);
    gate.close();
    expect(gate.reveal, 0);
  });

  test('one long pull can open the row and refresh together', () {
    final gate = AddFriendsPullGate();
    expect(gate.dragged(72 + 100, refreshDistance: 100), isTrue);
    expect(gate.open, isTrue);
  });
}
