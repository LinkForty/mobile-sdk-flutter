// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../link_forty.dart';

/// A [NavigatorObserver] that reports a `screen_view` to LinkForty whenever a
/// route becomes the top of the navigation stack, so you get screen-flow
/// tracking without instrumenting every screen.
///
/// Add it to your app's `navigatorObservers`:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [LinkFortyNavigatorObserver()],
///   // ...
/// )
/// ```
///
/// By default only routes with a non-empty `settings.name` are reported
/// (anonymous routes are ignored, which keeps screen names meaningful). Provide
/// [screenNameExtractor] to customize how a route maps to a screen name. Each
/// reported `screen_view` is stamped with the active last-click attribution
/// context, like any other event.
class LinkFortyNavigatorObserver extends NavigatorObserver {
  /// Optional override for deriving a screen name from a route. Return `null` to
  /// skip reporting for that route.
  final String? Function(Route<dynamic> route)? screenNameExtractor;

  LinkFortyNavigatorObserver({this.screenNameExtractor});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Returning to the previous screen counts as viewing it again.
    if (previousRoute != null) _report(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _report(newRoute);
  }

  void _report(Route<dynamic> route) {
    final name = (screenNameExtractor ?? _defaultName)(route);
    if (name == null || name.isEmpty) return;

    final sdk = LinkForty.instanceOrNull;
    if (sdk == null) return; // SDK not initialized yet — ignore.

    // Fire-and-forget; navigation must not await network/queue work.
    unawaited(sdk.trackScreenView(name));
  }

  static String? _defaultName(Route<dynamic> route) => route.settings.name;
}
