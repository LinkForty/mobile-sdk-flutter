
# LinkForty Flutter SDK

**Native Flutter SDK for deep linking, mobile attribution, and conversion tracking.**

[![Pub Version](https://img.shields.io/pub/v/linkforty_flutter.svg)](https://pub.dev/packages/linkforty_flutter)
[![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Deferred Deep Linking**: Match app installs to link clicks: exactly, from the Google Play install referrer on Android, and otherwise by privacy-compliant fingerprinting
- **Universal Links & App Links**: Full support for iOS Universal Links and Android App Links (HTTPS deep links)
- **Custom URL Schemes**: Handle custom app URL schemes
- **Event Tracking**: Track in-app events and conversions
- **Last-Click Attribution**: In-app events are automatically credited to the deep link that most recently opened the app
- **Screen-Flow Tracking**: Report screen views (manually or automatically via a `NavigatorObserver`) to see what users do after clicking a link
- **Offline Support**: Queue events when offline with automatic retry
- **Privacy-First**: Never collects IDFA or GAID, and never shows the App Tracking Transparency prompt
- **Programmatic Link Creation**: Create short links directly from your app
- **Pure Dart/Flutter**: 100% Dart, standard `Future`/`Stream` APIs

## Requirements

- Flutter 3.38.1+
- Dart 3.10+
- iOS 13.0+
- Android API 24+ (`minSdk 24`)

These follow from the SDK's dependencies: every version of `app_links` it accepts needs iOS 13 and Android API 24, and the oldest needs Flutter 3.38.1.

## Installation

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  linkforty_flutter: ^0.6.0
```

Or run:

```bash
flutter pub add linkforty_flutter
```

## Quick Start

### 1. Initialize the SDK

Initialize the SDK once, in your `main.dart` or early in your app lifecycle.

```dart
import 'package:linkforty_flutter/linkforty_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize LinkForty
  try {
    final config = LinkFortyConfig(
      // Your LinkForty server: https://api.linkforty.com on the hosted service,
      // or the URL of your own LinkForty Core server.
      baseURL: Uri.parse('https://api.linkforty.com'),
      // Your workspace's app token. Required on the hosted service: it limits
      // install matching to your own links. Safe to ship in the app.
      appToken: 'at_your_app_token',
      apiKey: 'your-api-key', // Only needed to create links from the app (createLink)
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

Register a callback after `initialize()` returns. It receives the link the app was installed from, or `null` for an organic install. It is called once, on the launch that reports the install; later launches don't call it, and the attribution stays available from `getInstallData()`.

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

#### How certain is the match?

On Android, the SDK reads the Google Play install referrer on the launch that reports the install (waiting at most 2 seconds) and sends it with the install. A LinkForty link puts its click id in the referrer of the Play listing it sends a visitor to, so a server on `@linkforty/core` 1.41.1 or later matches the install to that exact click: `attributionMethod` is `"install_referrer"`, `confidenceScore` 100 and `competingLinks` 0. Otherwise (iOS, another store, a sideload, no answer from Play) the deferred deep link is matched to a click by device fingerprint. Either way, `DeepLinkData` carries the match details:

| Field | Type | Meaning |
|-------|------|---------|
| `confidenceScore` | `double?` | Confidence of the match, 0-100. |
| `matchedFactors` | `List<String>?` | Which factors matched the click (`["install_referrer"]` for a referrer match). |
| `attributionMethod` | `String?` | How the install was matched (`"install_referrer"` or `"fingerprint"`). |
| `competingLinks` | `int?` | How many other links had a click from the install's network that also reached the confidence threshold. |

`competingLinks` is `0` when no other link was in contention. Above `0`, another device's tap may be what led to this install, so an app acting on a sensitive link (a sign-in, a gift) can treat the match as unverified, for example by asking the user to confirm:

```dart
LinkForty.instance.onDeferredDeepLink((deepLinkData) {
  if (deepLinkData == null) return;

  if ((deepLinkData.competingLinks ?? 0) > 0) {
    // Ask the user to confirm before redeeming the invite.
    showConfirmInviteDialog(deepLinkData);
  } else {
    redeemInvite(deepLinkData);
  }
});
```

These fields are `null` on a direct deep link (`onDeepLink`), which is not an install match. The `InstallResponse` returned by `initialize()` carries `attributionMethod` (`"install_referrer"`, `"fingerprint"`, or `"none"` for an organic install) and `competingLinks` as well, on the launch that reports the install; on later launches both are `null`.

### 3. Handle Direct Deep Links (Universal Links / App Links)

The SDK listens for incoming links itself (via `app_links`), including the link that launched the app from a terminated state. Register a callback after `initialize()` returns: a link that arrived before any callback was registered is delivered to the first one.

You don't need your own `app_links` listener. If you have one from an earlier version, remove it; if you keep it, the SDK ignores the same URL passed to `handleDeepLink()` again within 10 seconds. Use `handleDeepLink()` for links that reach the app some other way, such as a push notification payload.

**Turn off Flutter's built-in deep linking** (see [Platform Setup](#turn-off-flutters-built-in-deep-linking)). Since Flutter 3.27 it's on by default and conflicts with `app_links`: Flutter would also hand each link's path to your router, so a short link's `/abc123` opens a route that doesn't exist. With it off, all links, including your app's own, arrive through `onDeepLink`.

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

### Turn off Flutter's built-in deep linking

Since Flutter 3.27, Flutter's own deep link handling is on by default. Flutter's [breaking-change note](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change) says apps using a link package such as `app_links`, which this SDK uses, must opt out:

**Android**, inside the `<activity>` element of `AndroidManifest.xml`:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```

**iOS**, in `ios/Runner/Info.plist`:

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
```

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

2.  **Asset Links**: Ensure your `.well-known/assetlinks.json` is hosted on your domain, listing your package name and signing certificate's SHA-256 fingerprint. For Play Store builds, use the fingerprint from Play Console → App integrity: Google re-signs your app.
3.  **minSdk**: set `minSdk = 24` (or higher) in `android/app/build.gradle`.

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

- **No advertising IDs**: Never collects IDFA or GAID, and never shows the App Tracking Transparency prompt.
- **How installs are matched**: on Android, from the Google Play install referrer when the install came from a link to Google Play; otherwise by probabilistic fingerprinting of the signals below.
- **Install ID**: The SDK stores the install ID your server assigns when the install is reported, to tie your app's events to that install. `clearData()` deletes it, with any cached attribution and queued events.
- **Data Minimization**: Collects only necessary attribution data.

### Data Collected (for attribution only)

- Device timezone
- Device language
- Screen resolution
- Platform and OS version (Android/iOS)
- App version
- User-Agent string
- The Google Play install referrer (Android, on the launch that reports the install)
- A device ID, only if your app passes one to `initialize(deviceId: ...)`

### HTTPS Required

The SDK enforces HTTPS for all API endpoints (except localhost, 127.0.0.1, and 10.0.2.2 for development).

## Support

- **Documentation**: https://docs.linkforty.com
- **Issues**: [GitHub Issues](https://github.com/LinkForty/mobile-sdk-flutter/issues)

## License

LinkForty Flutter SDK is available under the MIT license. See [LICENSE](LICENSE) for more info.
