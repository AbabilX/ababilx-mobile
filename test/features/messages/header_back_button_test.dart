import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat-header/header_back_button.dart';

void main() {
  testWidgets('the blur is clipped to the 40dp circle, not the toolbar slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: kToolbarHeight,
            child: NavigationToolbar(
              leading: HeaderBackButton(onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ClipOval)), const Size(40, 40));
    expect(tester.getSize(find.byType(BackdropFilter)), const Size(40, 40));
  });
}
