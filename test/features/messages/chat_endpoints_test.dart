import 'package:ababilx/core/constants/api_constants.dart';
import 'package:ababilx/features/messages/data/chat_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const endpoints = ChatEndpoints();

  group('conversation endpoints never end in a slash', () {
    // Gin does not route `/api/chat/conversations/<id>/`; it answers the
    // trailing slash with a 307 redirect, which Dio raises as a bad response.
    // Deleting a group failed on exactly that.
    test('an empty action addresses the conversation itself', () {
      expect(endpoints.action('c1', ''), '/api/chat/conversations/c1');
    });

    test('a named action still hangs off the conversation', () {
      expect(
        endpoints.action('c1', 'members/u2'),
        '/api/chat/conversations/c1/members/u2',
      );
      expect(endpoints.action('c1', 'read'), '/api/chat/conversations/c1/read');
    });

    test('the path builder itself refuses to append nothing', () {
      expect(
        ApiConstants.independentChatConversationAction('c1', ''),
        ApiConstants.independentChatConversation('c1'),
      );
    });
  });

  // Chat is independent of workspaces on the server (migration 0145), so the
  // app speaks one route set whatever the account's workspace situation.
  test('no chat route is a workspace route', () {
    final paths = [
      endpoints.conversations,
      endpoints.dm,
      endpoints.forward,
      endpoints.search,
      endpoints.callLog,
      endpoints.messages('c1'),
      endpoints.message('m1'),
      endpoints.reactions('m1'),
      endpoints.action('c1', 'leave'),
      endpoints.action('c1', 'members'),
      endpoints.media('c1'),
      endpoints.report('c1'),
      endpoints.groupsInCommon('u1'),
      endpoints.publicKey('u1'),
    ];
    for (final path in paths) {
      expect(path, startsWith('/api/chat/'), reason: path);
    }
  });
}
