import 'dart:math';

import 'package:ababilx/features/onboarding/profile-setup/random_profile.dart';
import 'package:ababilx/features/settings/display-name/display_name_rules.dart';
import 'package:ababilx/features/settings/username/username_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Skip values pass the same rules as typed ones', () {
    final random = Random(7);
    for (var i = 0; i < 500; i++) {
      final name = RandomProfile.name(random);
      expect(isValidDisplayName(name), isTrue, reason: name);
      final handle = RandomProfile.username(name, random);
      expect(isValidUsername(handle), isTrue, reason: handle);
      expect(normalizeUsername(handle), handle);
    }
  });

  test('a name with nothing usable still gives a valid handle', () {
    expect(isValidUsername(RandomProfile.username('😀')), isTrue);
    expect(
      isValidUsername(RandomProfile.username('A very long name ' * 4)),
      isTrue,
    );
  });
}
