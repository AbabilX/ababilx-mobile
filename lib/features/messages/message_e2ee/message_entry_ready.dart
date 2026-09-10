import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reset by the router on each auth transition. Only the post-login check sets
/// this; a notification/deep link cannot bypass the recovery choice.
final messageEntryReadyProvider = StateProvider<bool>((ref) => false);
