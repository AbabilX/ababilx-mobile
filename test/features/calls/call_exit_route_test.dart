import 'package:ababilx/features/calls/call_exit_route.dart';
import 'package:ababilx/features/chat-lock/data/chat_lock_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a finished call returns to its chat', () {
    expect(callExitRoute('c1', const {}), '/messages/c1');
  });

  test('a call with no chat returns to the list', () {
    expect(callExitRoute(null, const {}), '/messages');
    expect(callExitRoute('', const {}), '/messages');
  });

  test('a locked chat is never opened by a call ending', () {
    // The call may have ended on a locked phone, or with the phone in a
    // pocket: opening the chat would put its lock prompt up for nobody.
    expect(
      callExitRoute('c1', const {'c1': ChatLockMethod.device}),
      '/messages',
    );
    expect(
      callExitRoute('c2', const {'c1': ChatLockMethod.password}),
      '/messages/c2',
    );
  });
}
