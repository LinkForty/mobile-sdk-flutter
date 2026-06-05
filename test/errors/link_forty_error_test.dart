import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/errors/link_forty_error.dart';

void main() {
  group('LinkFortyError', () {
    test('NetworkError extracts message correctly', () {
      final exception = Exception('Failed to connect');
      final error = NetworkError(exception);
      expect(error.message, contains('Failed to connect'));
      expect(error.message, isNot(contains('Exception: ')));
    });

    test('InvalidResponseError builds correct message', () {
      final error = InvalidResponseError(
        statusCode: 404,
        responseMessage: 'Not Found',
      );
      expect(error.toString(), contains('status: 404'));
      expect(error.toString(), contains('Not Found'));
    });

    test('NotInitializedError has correct message', () {
      const error = NotInitializedError();
      expect(error.message, contains('not initialized'));
    });

    test('MissingApiKeyError has correct message', () {
      const error = MissingApiKeyError();
      expect(error.message, contains('API key is required'));
    });
  });
}
