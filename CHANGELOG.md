## 0.6.0

* **Google Play install referrer.** On Android, the launch that reports the install reads the Play install referrer and sends it as `installReferrer`. A LinkForty link puts its click id in the referrer of the Play listing it sends a visitor to, so a server on `@linkforty/core` 1.41.1 or later matches the install to that exact click: `attributionMethod` is `"install_referrer"`, `confidenceScore` 100, `matchedFactors` `["install_referrer"]` and `competingLinks` 0. The SDK waits at most 2 seconds for Play and asks once more after a failed read; without a referrer (iOS, another store, a sideload, no answer) the install is matched by fingerprint as before.
* Adds the `android_play_install_referrer` plugin (Android only), which brings `com.android.installreferrer` 2.2 and its `BIND_GET_INSTALL_REFERRER_SERVICE` permission. It is a normal permission: Android grants it without asking the user.

## 0.5.0

* **Install-match certainty.** The deferred deep link passed to `onDeferredDeepLink` now carries `confidenceScore`, `matchedFactors`, `attributionMethod` (`"fingerprint"`) and `competingLinks`. `competingLinks` counts the other links that had a click from the install's network that also reached the confidence threshold: `0` means no other link was in contention, and above `0` another device's tap may be what led to the install, so an app acting on a sensitive link (a sign-in, a gift) can ask the user to confirm. All four are `null` on a direct deep link.
* `InstallResponse` has `attributionMethod` (`"fingerprint"` or `"none"`) and `competingLinks` on the launch that reports the install. They are `null` on later launches, and when the server does not send them.
* The new fields are stored with the install's deep link, so `getInstallData()` returns them on later launches. Install data saved by earlier versions still loads, with the new fields `null`.
* An unexpected value in any of these fields is read as `null`, without affecting the rest of the response.

## 0.4.0

* **Behavior change:** `onDeferredDeepLink` is called once, on the launch that reports the install, with the link the app was installed from or `null` for an organic install. It was called on every launch with the attribution recorded at install, so an app had to record that it had handled the link itself. Later launches don't call it; the attribution stays available from `getInstallData()`. If your app kept its own "already handled" flag for the deferred deep link, it can be removed. This matches the iOS, Android, React Native and Expo SDKs.

## 0.3.2

* **Fixed:** `trackEvent`, `trackRevenue` and `trackScreenView` succeed when the server stores the event. The event endpoint replies `{"eventId", "acknowledged"}`, and the SDK expected a `success` field it has never sent, so every call threw a `DecodingError` after the event was stored, queued it, and sent it again on each flush and on later launches, from the persisted queue. Events queued on a device by earlier versions are sent once more and then leave the queue.
* An event is queued only when it may succeed later (no connection, or a 5xx response). An event the server rejects with a 4xx is reported and not queued, and a queued event the server rejects is dropped instead of being retried on every flush.
* A queued event that fails again keeps its place at the head of the queue, so events are sent in the order they were tracked.

## 0.3.1

* **Fixed:** installs reported without a `deviceId` are recorded and attributed. The field is left out of the install request when there is no value, instead of being sent as `null`, which the install endpoint rejects. Recommended for every app that doesn't pass `deviceId` to `initialize()`: deferred deep links depend on it.
* **Fixed:** the fingerprint reports the device's IANA timezone (for example `America/Los_Angeles`) instead of an abbreviation (`PDT`), so it matches the timezone the server records for a browser click and counts toward install attribution. The timezone is read through the [`flutter_timezone`](https://pub.dev/packages/flutter_timezone) plugin, which replaces the `timezone` package; the abbreviation is still sent on a platform that can't report an identifier.

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
