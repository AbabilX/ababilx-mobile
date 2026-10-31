import 'package:ababilx/features/messages/chat-timeline/group_event_label.dart';
import 'package:ababilx/features/messages/chat-timeline/message_bubble.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/task/task_card.dart';
import 'package:ababilx/features/messages/task/task_card_data.dart';
import 'package:ababilx/features/messages/task/task_event_label.dart';
import 'package:ababilx/features/messages/task/task_list_provider.dart';
import 'package:ababilx/features/messages/task/task_strings.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage task({
  String id = 'm1',
  String title = 'Fix login',
  String description = 'Crashes on\nbad password',
  String priority = 'high',
  String status = 'todo',
  MessageSendStatus send = MessageSendStatus.sent,
}) => ChatMessage(
  id: id,
  conversationId: 'c1',
  userId: 'u1',
  body: encodeTiptapBody(plain: taskBodyText(title, description)),
  createdAt: '2026-10-07T10:00:00Z',
  sendStatus: send,
  meta: {
    'task': {'priority': priority, 'status': status},
  },
);

void main() {
  test('wire values are the server\'s', () {
    expect(
      [for (final p in TaskPriority.values) p.wire],
      ['low', 'medium', 'high', 'urgent'],
    );
    expect(
      [for (final s in TaskStatus.values) s.wire],
      ['todo', 'in_progress', 'review', 'blocked', 'done', 'cancelled'],
    );
  });

  test('a body round-trips to title and description', () {
    final text = taskText(task());
    expect(text.title, 'Fix login');
    expect(text.description, 'Crashes on\nbad password');
    expect(taskText(task(description: '')).description, '');
    expect(taskBodyText('Two\nlines', ''), 'Two lines');
  });

  test('only a message with meta.task is a card', () {
    expect(TaskCardData.of(task())!.priority, TaskPriority.high);
    expect(
      TaskCardData.of(task(status: 'in_progress'))!.status,
      TaskStatus.inProgress,
    );
    const plain = ChatMessage(
      id: 'm2',
      conversationId: 'c1',
      userId: 'u1',
      body: 'hi',
      createdAt: '2026-10-07T10:00:00Z',
    );
    expect(TaskCardData.of(plain), isNull);
    // A value from a newer server falls back rather than breaking the card.
    expect(TaskCardData.of(task(status: 'archived'))!.status, TaskStatus.todo);
  });

  test('moving a task keeps the rest of meta', () {
    final message = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      userId: 'u1',
      body: 'x',
      createdAt: '2026-10-07T10:00:00Z',
      meta: const {
        'private_quote_id': 'q',
        'task': {'priority': 'low', 'status': 'todo', 'updated_by': 'u2'},
      },
    );
    final moved = message.copyWith(
      meta: taskMetaWith(message, status: TaskStatus.done),
    );
    expect(moved.meta!['private_quote_id'], 'q');
    expect(moved.meta!['task'], {
      'priority': 'low',
      'status': 'done',
      'updated_by': 'u2',
    });
    expect(moved == message, isFalse);
  });

  test('filters split open from closed', () {
    final all = [
      task(id: 'a'),
      task(id: 'b', status: 'done'),
      task(id: 'c', status: 'blocked'),
      task(id: 'd', status: 'cancelled'),
    ];
    expect(
      [for (final m in filterTasks(all, TaskFilter.open)) m.id],
      ['a', 'c'],
    );
    expect(
      [for (final m in filterTasks(all, TaskFilter.closed)) m.id],
      ['b', 'd'],
    );
    expect(filterTasks(all, TaskFilter.all).length, 4);
  });

  testWidgets('change lines name the actor and the new value', (tester) async {
    ChatMessage line(String event, String value, String actor) => ChatMessage(
      id: 's1',
      conversationId: 'c1',
      userId: actor,
      body: 'Rahim marked a task as Done',
      createdAt: '2026-10-07T10:00:00Z',
      messageType: 'system',
      meta: {
        'event': event,
        'actor_id': actor,
        'actor_name': 'Rahim',
        'value': value,
        'message_id': 'm1',
      },
    );
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(
      taskEventLabel(context, line('task_status_changed', 'done', 'u2'), 'u1'),
      'Rahim marked a task as Done',
    );
    expect(
      taskEventLabel(
        context,
        line('task_priority_changed', 'urgent', 'u1'),
        'u1',
      ),
      'You set the priority of a task to Urgent',
    );
    final other = line('member_added', '', 'u2');
    expect(taskEventLabel(context, other, 'u1'), isNull);
    // An older build still reads the server's own sentence.
    expect(
      groupEventLabel(line('task_status_changed', 'done', 'u2'), 'u1'),
      'Rahim marked a task as Done',
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('card draws text and both dropdowns in ${brightness.name}', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        ),
      );
      final message = task(status: 'in_progress');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: TaskCard(
                    message: message,
                    task: TaskCardData.of(message)!,
                    colors: BubbleColors.of(
                      theme.colorScheme,
                      hasWallpaper: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      const s = TaskStrings(false);
      expect(find.text('Fix login'), findsOneWidget);
      expect(find.text('Crashes on\nbad password'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The dropdown is a bottom sheet listing every status, never a popup.
      await tester.tap(find.text('In progress'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(s.status), findsOneWidget);
      expect(find.byType(PopupMenuButton), findsNothing);
      for (final status in TaskStatus.values) {
        expect(find.text(s.statusName(status)), findsWidgets);
      }
      // Picking the value it already has changes nothing and sends nothing.
      await tester.tap(find.text('In progress').last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a card still sending cannot be changed', (tester) async {
    final message = task(send: MessageSendStatus.sending);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: TaskCard(
                message: message,
                task: TaskCardData.of(message)!,
                colors: BubbleColors.of(
                  ThemeData().colorScheme,
                  hasWallpaper: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
