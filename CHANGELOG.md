## 0.2.0

* The SDK now identifies itself on every request: a `sdkName` (`"flutter"`) and `sdkVersion` field is included on the install and event payloads, and an `X-LinkForty-SDK: flutter/<version>` header is sent on all requests. This lets the backend report which SDKs and versions are in use and flag outdated integrations. No API or integration changes are required.
* **Last-click attribution for in-app events.** Every tracked event is now stamped with the deep link that most recently opened the app (deferred install *or* direct re-engagement) plus an app-open `sessionId`, so the backend can credit in-app activity to the originating link. The newest deep-link open supersedes the previous one, and the active link is persisted across app restarts; events with no preceding deep-link open stay organic (session only). Fully automatic.
* **Screen-view tracking** for per-link screen-flow funnels. New `LinkForty.instance.trackScreenView(name)` and a `LinkFortyNavigatorObserver` (add it to your `MaterialApp.navigatorObservers` to auto-report named routes) emit `screen_view` events carrying the screen name, the previous screen, and the active attribution stamp.

## 0.1.1

* Update `device_info_plus` to `^13.1.0` and `package_info_plus` to `^10.1.0` (latest stable majors).

## 0.1.0

Initial release of the LinkForty Flutter SDK.

* Deferred deep linking with privacy-compliant device fingerprinting for install attribution.
* Universal Links / App Links and custom URL scheme handling via `app_links`.
* Server-side link resolution with automatic fallback to local URL parsing.
* Event and revenue tracking with an offline queue and automatic retry.
* Programmatic short-link creation from within the app.
* Install attribution data and install ID accessors.
* Configurable attribution window and debug logging.
