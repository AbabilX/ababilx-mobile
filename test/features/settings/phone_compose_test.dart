import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/settings/discovery/phone_compose.dart';
import 'package:ababilx/features/settings/discovery/phone_countries.dart';

void main() {
  final bd = phoneCountryByIso('BD')!;

  test('every country row parses, with no duplicate ISO code', () {
    expect(phoneCountries.length, greaterThan(180));
    expect(
      phoneCountries.map((c) => c.iso).toSet().length,
      phoneCountries.length,
    );
    for (final c in phoneCountries) {
      expect(c.iso.length, 2, reason: c.name);
      expect(int.tryParse(c.dial), isNotNull, reason: c.name);
    }
  });

  test('composes E.164 and drops the trunk zero', () {
    expect(composePhoneNumber(bd, '01712345678'), '+8801712345678');
    expect(composePhoneNumber(bd, '1712-345 678'), '+8801712345678');
    expect(
      composePhoneNumber(phoneCountryByIso('IT')!, '0612345678'),
      '+390612345678',
    );
  });

  test('empty clears, garbage and short numbers are refused', () {
    expect(composePhoneNumber(bd, '  '), '');
    expect(composePhoneNumber(bd, 'abc'), isNull);
    expect(composePhoneNumber(bd, '0'), isNull);
    expect(composePhoneNumber(bd, '123'), isNull);
  });

  test('a stored number finds its country by the longest code', () {
    expect(phoneCountryOfNumber('+8801712345678')!.iso, 'BD');
    expect(phoneCountryOfNumber('+12025550123')!.iso, 'US');
    expect(phoneCountryOfNumber('+18765550123')!.iso, 'JM');
    expect(phoneCountryOfNumber('+79161234567')!.iso, 'RU');
    expect(phoneCountryOfNumber('01712345678'), isNull);
    expect(nationalPartOf('+8801712345678', bd), '1712345678');
  });

  test('search matches name, code and ISO', () {
    expect(searchPhoneCountries('bangla').single.iso, 'BD');
    expect(searchPhoneCountries('+880').single.iso, 'BD');
    expect(searchPhoneCountries('bd').map((c) => c.iso), contains('BD'));
  });
}
