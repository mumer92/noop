# Repository Agent Instructions

## NOOP Device Build Bundle IDs

This machine installs NOOP under Muhammad Umer's personal bundle namespace. Never build or install a physical-device build with the upstream `com.noopapp.*` product bundle IDs, because iOS treats a bundle-ID change as a different app container and the existing local app data will not be used.

Before every pull, XcodeGen regeneration, physical-device build, or install, preserve or restore the local identifiers:

- `bundleIdPrefix: com.mumer`
- `APP_GROUP_ID: group.com.mumer.noop`
- `PRODUCT_BUNDLE_IDENTIFIER: com.mumer.noop` for the app targets
- `PRODUCT_BUNDLE_IDENTIFIER: com.mumer.strandtests`
- `PRODUCT_BUNDLE_IDENTIFIER: com.mumer.noop.widgets`
- `PRODUCT_BUNDLE_IDENTIFIER: com.mumer.noop.watch`
- `PRODUCT_BUNDLE_IDENTIFIER: com.mumer.noop.watch.complications`
- `WKCompanionAppBundleIdentifier: com.mumer.noop` in `project.yml` and `NOOPWatch/Info.plist`
- Swift app-group fallbacks as `group.com.mumer.noop` in `WatchScoreSnapshot.swift` and `WidgetSnapshot.swift`

The only `com.noopapp` identifier that should remain in `project.yml` for the local personal build is `com.noopapp.noop.debugexport`.

If a pull from `origin/main` or a project regeneration resets any signed target to `com.noopapp.*`, change it back to the matching `com.mumer.*` identifier before running `xcodegen generate`, building, or installing on the phone. Use the repo-local `update-and-install-device` skill for this workflow.
