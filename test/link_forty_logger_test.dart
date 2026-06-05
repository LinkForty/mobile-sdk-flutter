import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/link_forty_logger.dart';

void main() {
  group('LinkFortyLogger', () {
    test('debug mode is disabled by default', () {
      expect(LinkFortyLogger.isDebugEnabled, isFalse);
    });

    test('can toggle debug mode', () {
      LinkFortyLogger.isDebugEnabled = true;
      expect(LinkFortyLogger.isDebugEnabled, isTrue);

      LinkFortyLogger.isDebugEnabled = false;
      expect(LinkFortyLogger.isDebugEnabled, isFalse);
    });

    test('log methods do not crash when debug is disabled', () {
      LinkFortyLogger.isDebugEnabled = false;
      expect(() => LinkFortyLogger.log('test'), returnsNormally);
      expect(() => LinkFortyLogger.info('test'), returnsNormally);
      expect(() => LinkFortyLogger.warning('test'), returnsNormally);
      expect(() => LinkFortyLogger.logError('test'), returnsNormally);
    });

    test('log methods do not crash when debug is enabled', () {
      LinkFortyLogger.isDebugEnabled = true;
      expect(() => LinkFortyLogger.log('test'), returnsNormally);
      expect(() => LinkFortyLogger.info('test'), returnsNormally);
      expect(() => LinkFortyLogger.warning('test'), returnsNormally);
      expect(
        () => LinkFortyLogger.logError('test', Exception('error')),
        returnsNormally,
      );
    });
  });
}
