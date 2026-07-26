import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Allows a shell child to temporarily hide the floating bottom bar while a
/// full-width modal surface is open.
final shellBottomBarHiddenProvider = StateProvider<bool>((ref) => false);
