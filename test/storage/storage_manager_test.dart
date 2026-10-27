import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/storage/storage_manager.dart';
import 'package:linkforty_flutter/storage/storage_keys.dart';
import 'package:linkforty_flutter/models/deep_link_data.dart';

import 'storage_manager_test.mocks.dart';

@GenerateMocks([SharedPreferencesProtocol])
void main() {
  late MockSharedPreferencesProtocol mockPrefs;
  late StorageManager storageManager;

  setUp(() {
    mockPrefs = MockSharedPreferencesProtocol();
    storageManager = StorageManager(mockPrefs);
  });

  group('StorageManager', () {
    test('saveInstallId saves correctly', () async {
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

      final result = await storageManager.saveInstallId('id_123');

      verify(mockPrefs.setString(StorageKeys.installId, 'id_123')).called(1);
      expect(result, isTrue);
    });

    test('getInstallId returns stored value', () {
      when(mockPrefs.getString(StorageKeys.installId)).thenReturn('id_123');

      final result = storageManager.getInstallId();

      expect(result, 'id_123');
    });

    test('saveInstallData encodes and saves json', () async {
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
      final data = DeepLinkData(shortCode: 'abc');

      final result = await storageManager.saveInstallData(data);

      verify(mockPrefs.setString(StorageKeys.installData, any)).called(1);
      expect(result, isTrue);
    });

    test('getInstallData decodes stored json', () {
      final json = '{"shortCode": "abc"}';
      when(mockPrefs.getString(StorageKeys.installData)).thenReturn(json);

      final result = storageManager.getInstallData();

      expect(result?.shortCode, 'abc');
    });

    test(
      'getInstallData restores the match certainty fields it saved',
      () async {
        String? saved;
        when(mockPrefs.setString(StorageKeys.installData, any)).thenAnswer((
          invocation,
        ) async {
          saved = invocation.positionalArguments[1] as String;
          return true;
        });
        const data = DeepLinkData(
          shortCode: 'abc',
          confidenceScore: 88,
          matchedFactors: ['ip', 'ua'],
          attributionMethod: 'fingerprint',
          competingLinks: 1,
        );

        await storageManager.saveInstallData(data);
        when(mockPrefs.getString(StorageKeys.installData)).thenReturn(saved);

        expect(storageManager.getInstallData(), equals(data));
      },
    );

    test('getInstallData decodes data saved without the certainty fields', () {
      when(mockPrefs.getString(StorageKeys.installData)).thenReturn(
        '{"shortCode":"abc","iosUrl":null,"androidUrl":null,"webUrl":null,'
        '"utmParameters":null,"customParameters":{"promo":"1"},'
        '"deepLinkPath":"/p/1","appScheme":"myapp",'
        '"clickedAt":"2026-01-15T10:30:00.000Z","linkId":"link_1"}',
      );

      final result = storageManager.getInstallData();

      expect(result?.shortCode, 'abc');
      expect(result?.linkId, 'link_1');
      expect(result?.customParameters, {'promo': '1'});
      expect(result?.confidenceScore, isNull);
      expect(result?.matchedFactors, isNull);
      expect(result?.attributionMethod, isNull);
      expect(result?.competingLinks, isNull);
    });

    test('isFirstLaunch returns true if key invalid or missing', () {
      when(mockPrefs.getBool(StorageKeys.firstLaunch)).thenReturn(null);
      expect(storageManager.isFirstLaunch(), isTrue);

      when(mockPrefs.getBool(StorageKeys.firstLaunch)).thenReturn(false);
      expect(storageManager.isFirstLaunch(), isTrue);
    });

    test('isFirstLaunch returns false if key is true', () {
      // Logic: isFirstLaunch returns !hasLaunched
      // If cached value is true (hasLaunched=true), then isFirstLaunch should be false
      when(mockPrefs.getBool(StorageKeys.firstLaunch)).thenReturn(true);
      expect(storageManager.isFirstLaunch(), isFalse);
    });

    test('clearAll removes all keys', () async {
      when(mockPrefs.remove(any)).thenAnswer((_) async => true);

      final result = await storageManager.clearAll();

      verify(mockPrefs.remove(StorageKeys.installId)).called(1);
      verify(mockPrefs.remove(StorageKeys.installData)).called(1);
      verify(mockPrefs.remove(StorageKeys.firstLaunch)).called(1);
      expect(result, isTrue);
    });
  });
}
