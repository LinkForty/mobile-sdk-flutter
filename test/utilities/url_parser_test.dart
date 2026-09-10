import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/utilities/url_parser.dart';

void main() {
  group('URLParser', () {
    group('extractShortCode', () {
      test('extracts short code from valid URL', () {
        final url = Uri.parse('https://example.com/abc12345');
        expect(URLParser.extractShortCode(url), 'abc12345');
      });

      test('returns null for root URL', () {
        final url = Uri.parse('https://example.com/');
        expect(URLParser.extractShortCode(url), isNull);
      });
    });

    group('extractUTMParameters', () {
      test('extracts all UTM parameters', () {
        final url = Uri.parse(
          'https://example.com/link?utm_source=google&utm_medium=cpc&utm_campaign=summer&utm_term=shoes&utm_content=banner',
        );
        final utm = URLParser.extractUTMParameters(url);
        expect(utm?.source, 'google');
        expect(utm?.medium, 'cpc');
        expect(utm?.campaign, 'summer');
        expect(utm?.term, 'shoes');
        expect(utm?.content, 'banner');
      });

      test('returns null if no UTM parameters', () {
        final url = Uri.parse('https://example.com/link?id=123');
        final utm = URLParser.extractUTMParameters(url);
        expect(utm, isNull);
      });

      test('extracts partial UTM parameters', () {
        final url = Uri.parse('https://example.com/link?utm_source=google');
        final utm = URLParser.extractUTMParameters(url);
        expect(utm?.source, 'google');
        expect(utm?.medium, isNull);
      });
    });

    group('extractCustomParameters', () {
      test('extracts non-UTM parameters', () {
        final url = Uri.parse(
          'https://example.com/link?utm_source=google&ref=friend&promo=true',
        );
        final params = URLParser.extractCustomParameters(url);
        expect(params['ref'], 'friend');
        expect(params['promo'], 'true');
        expect(params.containsKey('utm_source'), isFalse);
      });

      test('returns empty map if no params', () {
        final url = Uri.parse('https://example.com/link');
        final params = URLParser.extractCustomParameters(url);
        expect(params, isEmpty);
      });
    });

    group('parseDeepLink', () {
      test('parses comprehensive deep link', () {
        final url = Uri.parse(
          'https://go.example.com/abc12345?utm_source=email&referral=user1',
        );
        final data = URLParser.parseDeepLink(url);

        expect(data?.shortCode, 'abc12345');
        expect(data?.utmParameters?.source, 'email');
        expect(data?.customParameters?['referral'], 'user1');
        expect(data?.iosURL, url.toString());
      });

      test('returns null if no short code', () {
        final url = Uri.parse('https://go.example.com/');
        final data = URLParser.parseDeepLink(url);
        expect(data, isNull);
      });
    });

    group('isReservedParameter', () {
      test('covers the names LinkForty consumes', () {
        // utm_* is surfaced separately as utmParameters; fp_* are fingerprint
        // signals the redirect reads server-side; lf_click is the id appended
        // to a destination URL. The server's extractor excludes all three.
        expect(URLParser.isReservedParameter('utm_source'), isTrue);
        expect(URLParser.isReservedParameter('fp_tz'), isTrue);
        expect(URLParser.isReservedParameter('lf_click'), isTrue);
      });

      test('matches case-insensitively', () {
        expect(URLParser.isReservedParameter('UTM_Source'), isTrue);
        expect(URLParser.isReservedParameter('FP_TZ'), isTrue);
        expect(URLParser.isReservedParameter('LF_Click'), isTrue);
      });

      test('does not sweep up near-misses', () {
        expect(URLParser.isReservedParameter('slug'), isFalse);
        expect(URLParser.isReservedParameter('utmost'), isFalse);
        expect(URLParser.isReservedParameter('fps'), isFalse);
        expect(URLParser.isReservedParameter('lf_clicks'), isFalse);
      });
    });

    group('extractCustomParameters excludes reserved names', () {
      test('keeps only the app\'s own parameters', () {
        final url = Uri.parse(
          'https://example.com/abc12345?slug=titanic&utm_source=ig&fp_tz=UTC&lf_click=abc',
        );
        expect(URLParser.extractCustomParameters(url), {'slug': 'titanic'});
      });
    });
  });
}
