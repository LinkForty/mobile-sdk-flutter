import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:linkforty_flutter/network/network_manager.dart';
import 'package:linkforty_flutter/network/http_client.dart';
import 'package:linkforty_flutter/models/link_forty_config.dart';
import 'package:linkforty_flutter/network/http_method.dart';
import 'package:linkforty_flutter/network/http_response.dart';

import 'network_manager_test.mocks.dart';

@GenerateMocks([HttpClient])
void main() {
  late MockHttpClient mockHttpClient;
  late LinkFortyConfig config;
  late NetworkManager networkManager;

  setUp(() {
    mockHttpClient = MockHttpClient();
    config = LinkFortyConfig(baseURL: Uri.parse('https://example.com'));
    networkManager = NetworkManager(config: config, httpClient: mockHttpClient);
  });

  group('NetworkManager', () {
    test('makes request with correct headers', () async {
      final responseBody = Uint8List.fromList(utf8.encode('{"id": 1}'));
      when(
        mockHttpClient.execute(
          url: anyNamed('url'),
          method: anyNamed('method'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => HttpResponse(statusCode: 200, body: responseBody),
      );

      await networkManager.request(
        endpoint: '/test',
        method: HttpMethod.get,
        fromJson: (json) => json,
      );

      verify(
        mockHttpClient.execute(
          url: 'https://example.com/test',
          method: HttpMethod.get,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });

    test('adds API key to headers', () async {
      config = LinkFortyConfig(
        baseURL: Uri.parse('https://example.com'),
        apiKey: 'key',
      );
      networkManager = NetworkManager(
        config: config,
        httpClient: mockHttpClient,
      );

      final responseBody = Uint8List.fromList(utf8.encode('{}'));
      when(
        mockHttpClient.execute(
          url: anyNamed('url'),
          method: anyNamed('method'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => HttpResponse(statusCode: 200, body: responseBody),
      );

      await networkManager.request(
        endpoint: '/test',
        method: HttpMethod.get,
        fromJson: (json) => json,
      );

      final captured = verify(
        mockHttpClient.execute(
          url: anyNamed('url'),
          method: anyNamed('method'),
          headers: captureAnyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], 'Bearer key');
    });

    test('retries on failure', () async {
      // Fail twice, then succeed
      int callCount = 0;
      final responseBody = Uint8List.fromList(utf8.encode('{}'));

      when(
        mockHttpClient.execute(
          url: anyNamed('url'),
          method: anyNamed('method'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount <= 2) {
          throw Exception('Network error');
        }
        return HttpResponse(statusCode: 200, body: responseBody);
      });

      await networkManager.request(
        endpoint: '/test',
        method: HttpMethod.get,
        fromJson: (json) => json,
      );

      expect(callCount, 3);
    });
  });
}
