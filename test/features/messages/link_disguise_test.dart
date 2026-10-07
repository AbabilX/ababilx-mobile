import 'package:ababilx/features/messages/markdown/link_disguise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a label naming another site is a disguise', () {
    expect(
      disguisedLinkHost('bank.com', 'https://evil.example/login'),
      'evil.example',
    );
    expect(
      disguisedLinkHost('https://bank.com/pay', 'http://evil.example'),
      'evil.example',
    );
    expect(
      disguisedLinkHost('www.bank.com', 'https://bank.com.evil.example'),
      'bank.com.evil.example',
    );
    expect(
      disguisedLinkHost(' BANK.com ', 'https://notbank.com'),
      'notbank.com',
    );
  });

  test('the same site, with or without www or a subdomain, is not', () {
    expect(disguisedLinkHost('bank.com', 'https://bank.com/pay'), isNull);
    expect(
      disguisedLinkHost('https://www.bank.com', 'https://bank.com'),
      isNull,
    );
    expect(disguisedLinkHost('bank.com', 'https://docs.bank.com/a'), isNull);
    expect(disguisedLinkHost('docs.bank.com', 'https://bank.com'), isNull);
    // What an autolinked bare address looks like: label and target agree.
    expect(
      disguisedLinkHost('https://a.example/x?y=1', 'https://a.example/x?y=1'),
      isNull,
    );
  });

  test('a label of ordinary words makes no claim', () {
    expect(disguisedLinkHost('the report', 'https://evil.example'), isNull);
    expect(disguisedLinkHost('Click here', 'https://evil.example'), isNull);
    expect(disguisedLinkHost('v1.2 notes', 'https://evil.example'), isNull);
    expect(disguisedLinkHost('', 'https://evil.example'), isNull);
  });

  test('a target that is not a web page is left to the scheme check', () {
    expect(disguisedLinkHost('bank.com', 'mailto:a@evil.example'), isNull);
    expect(disguisedLinkHost('bank.com', 'tel:+8801712345678'), isNull);
  });
}
