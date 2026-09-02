import 'package:uuid/uuid.dart';

/// Stable idempotency key shared by the outbox, HTTP request, and WS event.
String newChatClientMessageId() => const Uuid().v4();
