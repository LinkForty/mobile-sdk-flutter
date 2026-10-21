// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import '../link_forty_logger.dart';
import '../models/event_request.dart';

/// A thread-safe in-memory queue for [EventRequest] objects.
///
/// The queue has a maximum capacity defined by [_maxQueueSize]. When the queue
/// is full, new events are dropped to prevent memory exhaustion.
class EventQueue {
  /// Maximum number of events to queue
  static const int _maxQueueSize = 100;

  /// Queued events
  final Queue<EventRequest> _queue = Queue<EventRequest>();

  /// Adds an [event] to the end of the queue.
  ///
  /// Returns `true` if the event was successfully added, or `false` if the
  /// queue has reached its capacity and the event was dropped.
  bool enqueue(EventRequest event) {
    if (_queue.length >= _maxQueueSize) {
      LinkFortyLogger.log(
        'Event queue full, dropping event: ${event.eventName}',
      );
      return false;
    }

    _queue.addLast(event);
    LinkFortyLogger.log(
      'Event queued: ${event.eventName} (queue size: ${_queue.length})',
    );
    return true;
  }

  /// Removes and returns the oldest [EventRequest] from the front of the queue.
  ///
  /// Returns `null` if the queue is empty.
  EventRequest? dequeue() {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }

  /// Puts [events] back at the front of the queue, oldest first, ahead of
  /// anything queued since. Events beyond capacity are dropped from the end.
  void requeueFront(List<EventRequest> events) {
    for (final event in events.reversed) {
      _queue.addFirst(event);
    }
    while (_queue.length > _maxQueueSize) {
      final dropped = _queue.removeLast();
      LinkFortyLogger.log(
          'Event queue full, dropping event: ${dropped.eventName}');
    }
  }

  /// Returns a snapshot of all events currently in the queue without removing them.
  List<EventRequest> peek() {
    return List<EventRequest>.from(_queue);
  }

  /// Clears all events from the queue
  void clear() {
    final count = _queue.length;
    _queue.clear();
    if (count > 0) {
      LinkFortyLogger.log('Event queue cleared ($count events removed)');
    }
  }

  /// Returns the number of queued events
  int get count => _queue.length;

  /// Checks if the queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Checks if the queue is full
  bool get isFull => _queue.length >= _maxQueueSize;
}
