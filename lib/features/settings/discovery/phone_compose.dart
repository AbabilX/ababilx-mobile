import 'discovery_settings.dart';
import 'phone_countries.dart';

/// The number typed after the country code, as the E.164 the server stores.
///
/// Empty stays empty (that clears the number); null means it is not a phone
/// number yet. The leading 0 people dial inside their own country is dropped
/// — "01712…" after +880 is +8801712…, not +88001712… — except in Italy,
/// where the 0 is part of the number.
String? composePhoneNumber(PhoneCountry country, String national) {
  var digits = national.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return national.trim().isEmpty ? '' : null;
  if (country.iso != 'IT') digits = digits.replaceFirst(RegExp(r'^0+'), '');
  if (digits.isEmpty) return null;
  return normalizePhoneNumber('+${country.dial}$digits');
}

/// The part of a stored E.164 number that follows [country]'s calling code.
String nationalPartOf(String e164, PhoneCountry country) {
  final prefix = '+${country.dial}';
  return e164.startsWith(prefix) ? e164.substring(prefix.length) : e164;
}
