import 'package:ababilx/shared/text/name_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldNameForSearch', () {
    test('strips the decoration around a name', () {
      // Stars, hearts and middle dots go. The Oriya digits in the ୨♡୧ bracket
      // stay — a digit is content, and "Murad 007" must stay findable by 007.
      expect(foldNameForSearch('⋆·˚ ♡ Murad ♡ ˚·⋆'), 'murad');
      expect(foldNameForSearch('⋆·˚ ୨♡୧ Murad ୨♡୧ ˚·⋆'), '୨୧ murad ୨୧');
      expect(foldNameForSearch('\u{1F512} Murad Hossain'), 'murad hossain');
    });

    test('folds styled Latin alphabets back to plain letters', () {
      expect(foldNameForSearch('𝙼𝚞𝚛𝚊𝚍'), 'murad');
      expect(foldNameForSearch('𝓜𝓾𝓻𝓪𝓭'), 'murad');
      expect(foldNameForSearch('Ｍｕｒａｄ'), 'murad');
      expect(foldNameForSearch('ⓂⓊⓇⒶⒹ'), 'murad');
      expect(foldNameForSearch('𝐌𝐮𝐫𝐚𝐝'), 'murad');
      expect(foldNameForSearch('𝕄𝕦𝕣𝕒𝕕'), 'murad');
    });

    test('folds the Letterlike holes in the math block', () {
      expect(foldNameForSearch('ℂℍℕℙℚℝℤ'), 'chnpqrz');
    });

    test('drops diacritics', () {
      expect(foldNameForSearch('José Ćurić'), 'jose curic');
      expect(foldNameForSearch('M̶u̶r̶a̶d̶'), 'murad');
    });

    test('leaves non-Latin scripts alone', () {
      expect(foldNameForSearch('⋆·˚ জীবনবড় ˚·⋆'), 'জীবনবড়');
    });

    test('is empty when a name has nothing to match on', () {
      expect(foldNameForSearch('⋆·˚ ♡ ˚·⋆'), '');
      expect(foldNameForSearch(null), '');
    });
  });

  group('matchesNameQuery', () {
    test('finds a decorated name by its plain letters', () {
      expect(matchesNameQuery('murad', ['⋆·˚ ୨♡୧ Murad ୨♡୧ ˚·⋆']), isTrue);
      expect(matchesNameQuery('murad', ['𝕄𝕦𝕣𝕒𝕕']), isTrue);
      expect(matchesNameQuery('MURAD', ['Ｍｕｒａｄ']), isTrue);
    });

    test('finds a plain name from a decorated query', () {
      expect(matchesNameQuery('𝕄𝕦𝕣', ['Murad Hossain']), isTrue);
    });

    test('matches any field, and an empty query matches everything', () {
      expect(matchesNameQuery('devmoz', ['⋆ ⋆', 'devmozadded']), isTrue);
      expect(matchesNameQuery('', ['anything']), isTrue);
      expect(matchesNameQuery('   ', ['anything']), isTrue);
    });

    test('still rejects a genuine miss', () {
      expect(matchesNameQuery('murad', ['Alice', 'alice99']), isFalse);
      // A name with no letters cannot be matched by letters.
      expect(matchesNameQuery('m', ['⋆·˚ ♡ ˚·⋆']), isFalse);
    });
  });
}
