# Workflows

## Local Setup

- The Xcode project is generated from `Project.swift` with Tuist.
- Verified Tuist version in this workspace: 4.31.0.
- `Tuist/Config.swift` is intentionally committed so Tuist can locate the project root in worktree checkouts.
- Google Mobile Ads SDK is resolved through Tuist's Swift Package Manager integration and is currently test-banner-only.

```sh
tuist generate
open PhotoRava.xcworkspace
```

## Local Build

Check the generated workspace and schemes:

```sh
tuist generate
xcodebuild -list -workspace PhotoRava.xcworkspace
```

Build for the iOS Simulator:

```sh
tuist generate
xcodebuild -workspace PhotoRava.xcworkspace -scheme PhotoRava -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/PhotoRava-build CODE_SIGNING_ALLOWED=NO build
```

## Manual Verification

The repository does not currently include an automated test target. Use focused manual checks:

- Route flow:
  - Select photos with GPS metadata and photos without GPS metadata.
  - Confirm route generation completes and saved routes open in map and timeline views.
  - On supported iOS 26+ devices, confirm AI summary/geocoding assistance appears; otherwise confirm fallback output remains usable.
- EXIF flow:
  - Select one photo and then multiple photos.
  - Confirm preview, original preview, save, share, and batch export paths.
- Permissions:
  - Confirm `Settings` reflects photo and location permission changes.
  - Confirm the Info.plist diagnostics stay green.

## Marketing Screenshot Generation

The committed PNGs in `marketing-screenshots` are ready for README/App Store style use. To regenerate them from raw simulator screenshots:

```sh
swift marketing-screenshots/generate_marketing_screenshots.swift [input-directory] [output-directory]
```

- `input-directory` defaults to `marketing-screenshots/raw`.
- `output-directory` defaults to `marketing-screenshots`.
- The script expects source screenshots named `01-route-list-source.png` through `06-original-preview-source.png`.

## Release Notes

- Deployment target: iOS 17.0.
- The generated project uses Swift 5 language mode. Current Swift 6 migration warnings are visible during builds.
- Some AI code paths require iOS 26.0+ and supported devices, but guarded fallbacks keep the app usable elsewhere.
- AdMob defaults to Google's official demo IDs through build settings. For production builds, override `ADMOB_APPLICATION_IDENTIFIER` and `ADMOB_ROUTE_LIST_BANNER_AD_UNIT_IDENTIFIER` privately in the release environment; do not commit real production values.
- Release archive:

```sh
tuist generate
xcodebuild -workspace PhotoRava.xcworkspace -scheme PhotoRava -configuration Release -destination 'generic/platform=iOS' archive -archivePath /tmp/PhotoRava.xcarchive
```

- There is no Fastlane setup, export options file, CI workflow, or provisioning guide yet. Signing/export should be verified in Xcode before distribution.

## Troubleshooting

- `build.db` locked:
  - Add a unique `-derivedDataPath` and rebuild.
- Tuist workspace is stale:
  - Run `tuist generate` again after changing `Project.swift` or resource/source layout.
- Route generation is weak or empty:
  - Check photo permissions, GPS metadata, and whether selected photos can be mapped back to `PHAsset` records.
- Permission wording changes:
  - Keep `Derived/InfoPlists/PhotoRava-Info.plist`, `SettingsView.swift`, `privacy-policy.md`, and `support.md` aligned.
