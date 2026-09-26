import 'package:flutter/material.dart';

import '../../messages/data/models/chat_models.dart';
import '../data/khaam_payload.dart';
import 'khaam_open_screen.dart';

/// Opens a Khaam from its bubble. The receiver swipes it open; anybody else —
/// the sender, or the receiver a second time — goes straight to the card.
Future<void> openKhaam(
  BuildContext context, {
  required ChatMessage message,
  required KhaamPayload payload,
  required bool isOwn,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          KhaamOpenScreen(message: message, payload: payload, isOwn: isOwn),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    ),
  );
}
