import 'package:ababilx/features/messages/chat-header/header_menu_button.dart';
import 'package:ababilx/features/messages/chat-mute/mute_choice.dart';
import 'package:ababilx/features/messages/chat-mute/mute_flow.dart';
import 'package:ababilx/features/messages/chat-mute/mute_options_sheet.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _group = ChatConversation(
  id: 'g1',
  teamId: '',
  createdAt: '2026-09-27T00:00:00Z',
  type: 'group',
  name: 'Team',
);
const _dm = ChatConversation(
  id: 'd1',
  teamId: '',
  createdAt: '2026-09-27T00:00:00Z',
  type: 'dm',
  name: 'Alice',
  peerUserId: 'alice',
);

/// The user's rule for this feature: bottom sheets only, never a dialog.
void _expectNoDialog() {
  expect(find.byType(Dialog), findsNothing);
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.byType(DatePickerDialog), findsNothing);
  expect(find.byType(TimePickerDialog), findsNothing);
  expect(find.byType(PopupMenuButton), findsNothing);
}

/// Mounts a button that opens the options sheet; the returned getter reads
/// what the sheet answered.
Future<MuteChoice? Function()> _mountSheet(
  WidgetTester tester, {
  required bool allowMentionsOnly,
}) async {
  MuteChoice? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showMuteOptionsSheet(
                context,
                allowMentionsOnly: allowMentionsOnly,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  return () => picked;
}

class _MuteNotifier extends ChatNotifier {
  _MuteNotifier(this.conversation);

  final ChatConversation conversation;
  final calls = <MuteChoice?>[];

  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    channels: conversation.isDm ? const [] : [conversation],
    dms: conversation.isDm ? [conversation] : const [],
  );

  @override
  Future<void> setMute(String id, MuteChoice? choice) async {
    calls.add(choice);
  }
}

void main() {
  testWidgets('a group offers every option as one bottom sheet', (
    tester,
  ) async {
    final result = await _mountSheet(tester, allowMentionsOnly: true);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    for (final label in [
      'For 1 hour',
      'For 8 hours',
      'For 1 day',
      'For 1 week',
      'Always',
      'Only mentions',
      'Custom',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    _expectNoDialog();

    await tester.tap(find.text('For 8 hours'));
    await tester.pumpAndSettle();
    final choice = result();
    expect(choice?.duration, const Duration(hours: 8));
    expect(choice?.mentionsOnly, isFalse);
  });

  testWidgets('a DM has no "Only mentions" — every message is to you', (
    tester,
  ) async {
    await _mountSheet(tester, allowMentionsOnly: false);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Only mentions'), findsNothing);
    expect(find.text('Always'), findsOneWidget);
  });

  testWidgets('only mentions answers a mentions-only choice', (tester) async {
    final result = await _mountSheet(tester, allowMentionsOnly: true);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only mentions'));
    await tester.pumpAndSettle();
    final choice = result();
    expect(choice?.mentionsOnly, isTrue);
    expect(choice?.toBody()['mode'], 'mentions');
  });

  testWidgets('custom time is an inline wheel inside the same sheet', (
    tester,
  ) async {
    final result = await _mountSheet(tester, allowMentionsOnly: true);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Mute until'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    _expectNoDialog();

    // Back returns to the list without closing the sheet.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('For 1 hour'), findsOneWidget);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    final before = DateTime.now();
    await tester.tap(find.widgetWithText(FilledButton, 'Mute'));
    await tester.pumpAndSettle();
    final choice = result();
    // Default pick is about an hour ahead, on a 5-minute step.
    expect(choice?.until, isNotNull);
    expect(choice!.until!.isAfter(before), isTrue);
    expect(choice.until!.minute % 5, 0);
    expect(
      choice.until!.difference(before).inMinutes,
      inInclusiveRange(55, 70),
    );
  });

  testWidgets('muted: tapping unmutes at once, no sheet', (tester) async {
    final muted = _group.copyWith(muted: true);
    final notifier = _MuteNotifier(muted);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => changeConversationMute(context, ref, muted),
                child: const Text('bell'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bell'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(notifier.calls, [null]);
  });

  testWidgets('not muted: the choice from the sheet is written', (
    tester,
  ) async {
    final notifier = _MuteNotifier(_dm);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => changeConversationMute(context, ref, _dm),
                child: const Text('bell'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bell'));
    await tester.pumpAndSettle();
    expect(find.text('Only mentions'), findsNothing);
    await tester.tap(find.text('For 1 week'));
    await tester.pumpAndSettle();
    expect(notifier.calls.single?.duration, const Duration(days: 7));
  });

  testWidgets('header ⋮ opens a bottom sheet, then the mute options', (
    tester,
  ) async {
    final notifier = _MuteNotifier(_group);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(() => notifier)],
        child: const MaterialApp(
          home: Scaffold(
            body: HeaderMenuButton(conversation: _group, title: 'Team'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(HeaderMenuButton));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Mute notifications'), findsOneWidget);
    expect(find.text('Search in chat'), findsOneWidget);
    _expectNoDialog();

    await tester.tap(find.text('Mute notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only mentions'));
    await tester.pumpAndSettle();
    expect(notifier.calls.single?.mentionsOnly, isTrue);
  });

  testWidgets('header sheet says what the current mute is', (tester) async {
    final muted = _group.copyWith(muted: true, muteMode: 'mentions');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(() => _MuteNotifier(muted))],
        child: MaterialApp(
          home: Scaffold(
            body: HeaderMenuButton(conversation: muted, title: 'Team'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(HeaderMenuButton));
    await tester.pumpAndSettle();
    expect(find.text('Unmute notifications'), findsOneWidget);
    expect(find.text('Only mentions'), findsOneWidget);
  });
}
