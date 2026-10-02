import 'package:ababilx/features/auth/data/one_scan_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one-scan code carries link and history keys', () {
    final keys = parseOneScanKeys(
      'ababilx://desktop-login?t=abc123&k=LINK&h=HIST&hv=2',
    );
    expect(keys.linkKeyParam, 'LINK');
    expect(keys.historyKeyParam, 'HIST');
    expect(keys.historyVersion, 2);
  });

  test('desktop code: link key only', () {
    final keys = parseOneScanKeys('ababilx://desktop-login?t=abc&k=LINK');
    expect(keys.hasLinkKey, isTrue);
    expect(keys.hasHistoryKey, isFalse);
  });

  test('old sign-in code: plain sign-in', () {
    final keys = parseOneScanKeys('ababilx://desktop-login?t=abc');
    expect(keys.hasLinkKey, isFalse);
    expect(keys.hasHistoryKey, isFalse);
  });

  test('sign-in token is the t param alone', () {
    expect(signInTokenOf('ababilx://desktop-login?t=abc&k=X&h=Y'), 'abc');
    expect(signInTokenOf('ababilx://desktop-login?t=abc'), 'abc');
    expect(signInTokenOf('abc'), 'abc');
  });
}
