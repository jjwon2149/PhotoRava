# Reviewer Guide

This guide is for recruiters, interviewers, and external reviewers who want to understand PhotoRava quickly without reading every Swift file.

## Product Pitch

PhotoRava helps people turn scattered trip photos into a route history and export photos with polished EXIF information. The app focuses on two workflows:

1. Reconstruct a route from selected photos.
2. Create shareable EXIF-stamped images from one or more photos.

## Suggested Review Path

1. Start with `README.md` for screenshots, setup, and product scope.
2. Read `docs/architecture.md` for module boundaries and data flow.
3. Inspect the persistence models:
   - `PhotoRava/PhotoRava/Models/Route.swift`
   - `PhotoRava/PhotoRava/Models/PhotoRecord.swift`
4. Follow the route workflow:
   - `Views/Home/RouteListView.swift`
   - `Views/PhotoPicker/PhotoSelectionView.swift`
   - `Views/Analysis/AnalysisProgressView.swift`
   - `Services/RouteReconstructionService.swift`
5. Follow the EXIF workflow:
   - `Views/Exif/ExifStampRootView.swift`
   - `Services/ExifStampMetadataService.swift`
   - `Services/StampedImageRenderer.swift`

## Engineering Decisions Worth Noting

- SwiftData is used for local persistence because route/photo records are local-first app state.
- OCR is only used when GPS metadata is missing, which keeps the primary route path simple and avoids unnecessary processing.
- FoundationModels usage is isolated behind availability checks and fallback behavior.
- Public privacy/support docs are versioned with the app source so permission wording stays auditable.
- The committed Tuist manifest makes the project structure reviewable without depending on a local, untracked Xcode project.

## Current Gaps

- There is no automated test target yet.
- CI, signing, export options, and release automation are not configured.
- The generated project builds in Swift 5 language mode; Swift 6 concurrency warnings remain as migration work.
- Some route and EXIF flows still require manual validation with real or simulator photo-library data.
