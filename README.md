
# LinkForty Flutter SDK

**Native Flutter SDK for deep linking, mobile attribution, and conversion tracking.**

[![Pub Version](https://img.shields.io/pub/v/linkforty_flutter.svg)](https://pub.dev/packages/linkforty_flutter)
[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Deferred Deep Linking**: Match app installs to link clicks using privacy-compliant fingerprinting
- **Universal Links & App Links**: Full support for iOS Universal Links and Android App Links (HTTPS deep links)
- **Custom URL Schemes**: Handle custom app URL schemes
- **Event Tracking**: Track in-app events and conversions
- **Last-Click Attribution**: In-app events are automatically credited to the deep link that most recently opened the app
- **Screen-Flow Tracking**: Report screen views (manually or automatically via a `NavigatorObserver`) to see what users do after clicking a link
- **Offline Support**: Queue events when offline with automatic retry
- **Privacy-First**: No IDFA/GAID collection by default, complies with privacy requirements
- **Programmatic Link Creation**: Create short links directly from your app
- **Pure Dart/Flutter**: 100% Dart, standard `Future`/`Stream` APIs

## Requirements

- Flutter 3.10+
- Dart 3.0+
- iOS 12.0+
- Android API 21+

## Installation

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  linkforty_flutter: ^0.1.0
```

Or run:

```bash
flutter pub add linkforty_flutter
```

## Quick Start

### 1. Initialize the SDK

Initialize the SDK in your `main.dart` or early in your app lifecycle.

```dart
import 'package:linkforty_flutter/linkforty_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize LinkForty
  try {
    final config = LinkFortyConfig(
      baseURL: Uri.parse('https://go.yourdomain.com'),
      apiKey: 'your-api-key', // Optional for self-hosted
      debug: true, // Enable debug logging
      attributionWindowHours: 168, // 7 days
    );
    
    final response = await LinkForty.initialize(config: config);
    print('LinkForty initialized. Install ID: ${response.installId}');
    
  } catch (e) {
    print('LinkForty initialization failed: $e');
  }

  runApp(const MyApp());
}
```

### 2. Handle Deferred Deep Links (Install Attribution)

Register a callback to handle deferred deep links. This is triggered when the app is installed from a link.

```dart
// checking attribution status
LinkForty.instance.onDeferredDeepLink((deepLinkData) {
  if (deepLinkData != null) {
    // User installed from a link - navigate to content
    print("Install attributed to: ${deepLinkData.shortCode}");
    print("UTM Source: ${deepLinkData.utmParameters?.source ?? "none"}");

    // Navigate to the right content
    final productId = deepLinkData.customParameters?['productId'];
    if (productId != null) {
      navigatorKey.currentState?.pushNamed('/product', arguments: productId);
    }
  } else {
    // Organic install - no attribution
    print("Organic install");
  }
});
```

### 3. Handle Direct Deep Links (Universal Links / App Links)

The SDK uses `app_links` internally to handle incoming links. You just need to register a callback.

```dart
// Handle deep links when app is running or opened from background
LinkForty.instance.onDeepLink((uri, deepLinkData) {
  print("Deep link opened: $uri");
  
  if (deepLinkData != null) {
    print("Link data: $deepLinkData");
    // Navigate using deep link path (e.g., /products/123)
    if (deepLinkData.deepLinkPath != null) {
       navigatorKey.currentState?.pushNamed(deepLinkData.deepLinkPath!);
    }
  }
});
```

> **Server-side resolution:** When the SDK is initialized, deep links are automatically resolved via the server to provide enriched data including `deepLinkPath`, `appScheme`, and `linkId`. If the server is unreachable, the SDK falls back to local URL parsing.

### 4. Track Events

```dart
// Track a simple event
await LinkForty.instance.trackEvent('button_clicked');

// Track event with properties
await LinkForty.instance.trackEvent(
  'purchase',
  {
    'product_id': '123',
    'amount': 29.99,
    'currency': 'USD',
  },
);

// Track revenue
await LinkForty.instance.trackRevenue(
  amount: 29.99,
  currency: 'USD',
  properties: {'product_id': '123'},
);
```

Every event is automatically stamped with the deep link that most recently opened the app (last-click attribution), so the dashboard can show what users do *after* clicking a link. Events with no preceding deep-link open are reported as organic. No extra code is required.

### 5. Track Screen Views

Reporting screen views lets the dashboard build a per-link screen-flow funnel. Each `screen_view` carries the same last-click attribution stamp as other events.

**Automatic** — add `LinkFortyNavigatorObserver` to your app's `navigatorObservers`. Named routes are reported as they appear:

```dart
import 'package:linkforty_flutter/linkforty_flutter.dart';

MaterialApp(
  navigatorObservers: [LinkFortyNavigatorObserver()],
  // routes must have a name to be reported, e.g.:
  // Navigator.pushNamed(context, '/product');  or  RouteSettings(name: 'ProductDetail')
  // ...
);
```

**Manual** — call it yourself (e.g. for screens not driven by named routes):

```dart
await LinkForty.instance.trackScreenView('ProductDetail');
```

### 6. Create Links Programmatically

```dart
import 'package:linkforty_flutter/linkforty_flutter.dart';

// ...

final result = await LinkForty.instance.createLink(
  CreateLinkOptions(
    deepLinkParameters: {'route': 'VIDEO_VIEWER', 'id': 'vid123'},
    title: 'Check this out!',
    utmParameters: UTMParameters(source: 'app', campaign: 'share'),
  ),
);

print("Share this link: ${result.url}");
// e.g., "https://go.yourdomain.com/tmpl/abc123"
```

> **Note:** Requires an API key in `LinkFortyConfig`.

## Platform Setup

### Android

1.  **AndroidManifest.xml**: Add the intent filters for App Links (HTTPS) and Custom Schemes.

```xml
<activity ...>
    <!-- App Links (Standard HTTPS) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="go.yourdomain.com" />
    </intent-filter>

    <!-- Custom Scheme (Optional) -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="yourapp" />
    </intent-filter>
</activity>
```

2.  **Asset Links**: Ensure your `.well-known/assetlinks.json` is hosted on your domain.

### iOS

1.  **Universal Links**: Add the Associated Domains capability in Xcode.
    *   `applinks:go.yourdomain.com`
2.  **Custom URL Schemes**: Add your scheme in `Info.plist` under URL Types.
3.  **AASA File**: Ensure your `.well-known/apple-app-site-association` is hosted on your domain.

## Advanced Usage

### Self-Hosted LinkForty Core

If you're running your own LinkForty Core instance:

```dart
final config = LinkFortyConfig(
  baseURL: Uri.parse('https://links.yourcompany.com'),
  apiKey: null, // No API key needed for self-hosted
  debug: false,
);
await LinkForty.initialize(config: config);
```

### Retrieve Install Data

```dart
final installData = LinkForty.instance.getInstallData();
if (installData != null) {
  print("Short code: ${installData.shortCode}");
  print("UTM source: ${installData.utmParameters?.source ?? "none"}");
}

final installId = LinkForty.instance.getInstallId();
if (installId != null) {
  print("Install ID: $installId");
}
```

### Event Queue Management

```dart
// Check queued events count
final count = LinkForty.instance.queuedEventCount;

// Manually flush event queue
await LinkForty.instance.flushEvents();

// Clear event queue
LinkForty.instance.clearEventQueue();
```

### Clear Data (for testing)

```dart
await LinkForty.instance.clearData();

// Reset SDK to uninitialized state (only for testing)
LinkForty.instance.reset();
```

## Privacy & Security

### Privacy-First Design

- **No Persistent IDs**: Uses probabilistic fingerprinting only.
- **Data Minimization**: Collects only necessary attribution data.
- **User Control**: Provides `clearData()` for user data deletion.

### Data Collected (for attribution only)

- Device timezone
- Device language
- Screen resolution
- OS version (Android/iOS)
- App version
- User-Agent string

### HTTPS Required

The SDK enforces HTTPS for all API endpoints (except localhost, 127.0.0.1, and 10.0.2.2 for development).

## Support

- **Documentation**: https://docs.linkforty.com
- **Issues**: [GitHub Issues](https://github.com/LinkForty/mobile-sdk-flutter/issues)

## License

LinkForty Flutter SDK is available under the MIT license. See [LICENSE](LICENSE) for more info.
