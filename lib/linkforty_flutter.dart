// Copyright 2026 LinkForty. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// LinkForty SDK for Flutter.
///
/// Import this single library to access the full public API:
///
/// ```dart
/// import 'package:linkforty_flutter/linkforty_flutter.dart';
/// ```
library;

// Core entry point.
export 'link_forty.dart';

// Public deep-link callbacks.
export 'deeplink/deeplink_handler.dart'
    show DeferredDeepLinkCallback, DeepLinkCallback;

// Automatic screen-view tracking.
export 'navigation/link_forty_navigator_observer.dart';

// Public models.
export 'models/link_forty_config.dart';
export 'models/deep_link_data.dart';
export 'models/install_response.dart';
export 'models/create_link_options.dart';
export 'models/create_link_result.dart';
export 'models/utm_parameters.dart';

// Errors.
export 'errors/link_forty_error.dart';
