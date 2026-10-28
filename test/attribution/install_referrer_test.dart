import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/attribution/install_referrer.dart';

const referrer =
    'lf_click=11111111-2222-4333-8444-555555555555&utm_source=poster';

void main() {
  group('PlayInstallReferrer.read', () {
    test('reads nothing off Android', () async {
      var asked = false;
      final value = await PlayInstallReferrer.read(
        isAndroid: false,
        query: () async {
          asked = true;
          return referrer;
        },
      );
      expect(value, isNull);
      expect(asked, isFalse);
    });

    test('returns the referrer Play recorded', () async {
      expect(
        await PlayInstallReferrer.read(
          isAndroid: true,
          query: () async => referrer,
        ),
        referrer,
      );
    });

    test('returns null for an empty referrer', () async {
      expect(
        await PlayInstallReferrer.read(isAndroid: true, query: () async => ' '),
        isNull,
      );
      expect(
        await PlayInstallReferrer.read(
          isAndroid: true,
          query: () async => null,
        ),
        isNull,
      );
    });

    test('asks once more after a failed read', () async {
      var calls = 0;
      final value = await PlayInstallReferrer.read(
        isAndroid: true,
        query: () async {
          calls++;
          if (calls == 1) throw PlatformException(code: 'SERVICE_UNAVAILABLE');
          return referrer;
        },
      );
      expect(value, referrer);
      expect(calls, 2);
    });

    test('gives up after a second failure', () async {
      var calls = 0;
      final value = await PlayInstallReferrer.read(
        isAndroid: true,
        query: () async {
          calls++;
          throw PlatformException(code: 'FEATURE_NOT_SUPPORTED');
        },
      );
      expect(value, isNull);
      expect(calls, 2);
    });

    test('returns null without the plugin', () async {
      var calls = 0;
      final value = await PlayInstallReferrer.read(
        isAndroid: true,
        query: () async {
          calls++;
          throw MissingPluginException();
        },
      );
      expect(value, isNull);
      expect(calls, 1);
    });

    test('returns null when Play does not answer in time', () async {
      final started = DateTime.now();
      final value = await PlayInstallReferrer.read(
        isAndroid: true,
        timeout: const Duration(milliseconds: 100),
        query: () =>
            Future<String?>.delayed(const Duration(seconds: 5), () => referrer),
      );
      expect(value, isNull);
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 1)),
      );
    });
  });
}
