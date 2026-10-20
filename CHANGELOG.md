## 0.3.1

* **Fixed:** installs reported without a `deviceId` are recorded and attributed. The field is left out of the install request when there is no value, instead of being sent as `null`, which the install endpoint rejects. Recommended for every app that doesn't pass `deviceId` to `initialize()`: deferred deep links depend on it.
* **Fixed:** the fingerprint reports the device's IANA timezone (for example `America/Los_Angeles`) instead of an abbreviation (`PDT`), so it matches the timezone the server records for a browser click and counts toward install attribution. The timezone is read through the [`flutter_timezone`](https://pub.dev/packages/flutter_timezone) plugin, which replaces the `timezone` package; the abbreviation is still sent on a platform that can't report an identifier.
* The declared minimums are now Flutter 3.38.1 and Dart 3.10, the versions the SDK's dependencies already required.

## 0.3.0

* **The SDK now handles incoming links itself.** `initialize()` listens for App Links, Universal Links and custom-scheme URLs through `app_links`, including the link that launched the app from a terminated state, and delivers each to `onDeepLink` callbacks with the server-resolved link data.
* A link that arrives before any `onDeepLink` callback is registered is held and delivered to the callbacks registered by the next microtask, so registering after `await LinkForty.initialize(...)` receives the launch link.
* **Behavior change:** the same URL passed to `handleDeepLink()` again within 10 seconds is ignored. An app that already forwards links from its own `app_links` listener gets each link once rather than twice; that listener can now be removed.
* **`onDeferredDeepLink` is called with `null` for an organic install**, so an app can tell an organic install from one not yet reported.
* `LinkFortyConfig.attributionWindowHours` is now used when reporting the install. The `attributionWindowHours` argument to `initialize()` overrides it when given.
* Last-click attribution: the install link is recorded only on the launch that reports the install, and not over a direct deep link opened on that same launch.
* The example app registers its callbacks after `initialize()`.

## 0.2.3

* **Fixed:** in-app events, screen views and revenue events are accepted by the event endpoint. The event `timestamp` is sent in UTC (ISO 8601 with a trailing `Z`), and attribution fields with no value (`attributedLinkId`, `attributedClickId`, `linkOpenedAt`, `sessionId`) are left out of the request instead of being sent as `null`. Events already queued on a device are sent in the corrected form when the queue is flushed. Thanks to [@arman-uc](https://github.com/arman-uc) ([#11](https://github.com/LinkForty/mobile-sdk-flutter/pull/11), fixes [#10](https://github.com/LinkForty/mobile-sdk-flutter/issues/10)).

## 0.2.2

* **Fixed:** `InstallResponse.fromJson` no longer throws when the backend returns `deepLinkData: {}` for an organic (unattributed) install, which surfaced as an error out of `initialize()`. An empty — or otherwise unusable — `deepLinkData` object is now treated as "no deep link" (`null`), the same as an explicit `null`.

## 0.2.1

* **URL parameters are now delivered on a direct open** (app already installed), not just after a deferred install. A link shared as `?slug=titanic` previously returned only the link's stored configuration on a direct open, because `_resolveUrl` discarded the local parse of the tapped URL. `customParameters` now carries both, with URL values winning on a collision — the same precedence the server applies on the deferred path. `linkId`, `deepLinkPath`, `appScheme`, the store URLs and `utmParameters` remain server-provided.
* The reserved-parameter filter now excludes `fp_*` and `lf_click` in addition to the UTM keys, matching the server. Fingerprint signals and the click-correlation id could previously reach an app inside `customParameters` as if you had set them. Matching is now by prefix, so any `utm_` or `fp_` name is covered whatever the suffix.

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
