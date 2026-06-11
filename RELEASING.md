# Releasing

## Version — bump it in TWO places

Dart exposes no reliable runtime version for the package itself, so the version
the SDK reports to the backend is a hand-maintained constant. On every release,
update **both**:

1. `version:` in [`pubspec.yaml`](pubspec.yaml) — the published pub.dev version.
2. `SdkInfo.version` in [`lib/sdk_info.dart`](lib/sdk_info.dart) — the version the
   SDK reports at runtime (`sdkVersion` field on install/event payloads and the
   `X-LinkForty-SDK` header).

⚠️ **These two must match.** If they drift, version diagnostics on the backend
will report the wrong SDK version. (`SdkInfo.name` is fixed at `"flutter"` and
never changes.)

## Steps

1. Bump `version:` in `pubspec.yaml` **and** `SdkInfo.version` in `lib/sdk_info.dart` to the same value.
2. Run `dart run build_runner build --delete-conflicting-outputs` if any models changed.
3. Update `CHANGELOG.md` (add a `## <version>` entry at the top).
4. `flutter test` and `dart analyze` must pass.
5. Commit, tag, and `dart pub publish`.
