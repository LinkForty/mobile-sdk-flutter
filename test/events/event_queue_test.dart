import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/events/event_queue.dart';
import 'package:linkforty_flutter/models/event_request.dart';

void main() {
  group('EventQueue', () {
    late EventQueue queue;

    setUp(() {
      queue = EventQueue();
    });

    test('starts empty', () {
      expect(queue.isEmpty, isTrue);
      expect(queue.count, 0);
    });

    test('enqueue adds event', () {
      final event = EventRequest(
        installId: 'id',
        eventName: 'test',
        eventData: {},
      );

      final result = queue.enqueue(event);

      expect(result, isTrue);
      expect(queue.count, 1);
      expect(queue.isEmpty, isFalse);
    });

    test('dequeue removes oldest event', () {
      final event1 = EventRequest(
        installId: 'id',
        eventName: '1',
        eventData: {},
      );
      final event2 = EventRequest(
        installId: 'id',
        eventName: '2',
        eventData: {},
      );

      queue.enqueue(event1);
      queue.enqueue(event2);

      final dequeued1 = queue.dequeue();
      expect(dequeued1?.eventName, '1');
      expect(queue.count, 1);

      final dequeued2 = queue.dequeue();
      expect(dequeued2?.eventName, '2');
      expect(queue.count, 0);
    });

    test('returns null when dequeuing empty queue', () {
      expect(queue.dequeue(), isNull);
    });

    test('peek returns non-modifying list', () {
      final event = EventRequest(
        installId: 'id',
        eventName: '1',
        eventData: {},
      );
      queue.enqueue(event);

      final list = queue.peek();
      expect(list.length, 1);
      expect(list.first.eventName, '1');

      // Modify list shouldn't modify queue
      list.clear();
      expect(queue.count, 1);
    });

    test('clear removes all events', () {
      queue.enqueue(
        EventRequest(installId: 'id', eventName: '1', eventData: {}),
      );
      queue.enqueue(
        EventRequest(installId: 'id', eventName: '2', eventData: {}),
      );

      queue.clear();
      expect(queue.isEmpty, isTrue);
    });

    test('respects max queue size', () {
      // Assuming max size is 100 (based on implementation)
      for (int i = 0; i < 100; i++) {
        queue.enqueue(
          EventRequest(installId: 'id', eventName: '$i', eventData: {}),
        );
      }

      expect(queue.isFull, isTrue);

      // Try adding 101st event
      final result = queue.enqueue(
        EventRequest(installId: 'id', eventName: 'overflow', eventData: {}),
      );

      expect(result, isFalse);
      expect(queue.count, 100);
    });
  });
}
