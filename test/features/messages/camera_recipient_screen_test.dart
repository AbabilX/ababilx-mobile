import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/features/messages/chat-list/camera_send_flow.dart';
import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected camera recipient exposes a tappable send action', (
    tester,
  ) async {
    late BuildContext nestedContext;
    const recipient = ChatUserSummary(userId: 'u-1', name: 'Alice');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Stack(
            children: [
              Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) {
                    nestedContext = context;
                    return const SizedBox.expand();
                  },
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  child: SizedBox(
                    key: Key('shell-bottom-bar'),
                    height: 88,
                    width: double.infinity,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    showCameraRecipientPicker(nestedContext, const [recipient], _onePixelPng);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded).hitTestable(), findsOneWidget);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
  'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
