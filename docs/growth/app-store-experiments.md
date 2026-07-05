# App Store Growth Experiments

## Scope

This is a docs-only brief for App Store Product Page Optimization and Custom Product Pages. It prepares hypotheses, audience framing, screenshot order, copy direction, metrics, run rules, and decision criteria for later console work.

No App Store Connect action was performed in this task. The brief uses only the existing repository assets listed below and does not change App Store metadata, screenshots, product code, project settings, or ad configuration.

## References

- Apple Product Page Optimization: https://developer.apple.com/app-store/product-page-optimization/
- App Store Connect Product Page Optimization help: https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/overview-of-product-page-optimization/
- Apple Custom Product Pages: https://developer.apple.com/app-store/custom-product-pages/
- App Store product page guidance: https://developer.apple.com/app-store/product-page/
- Local workflow: `docs/workflows.md` Marketing Screenshot Generation

## Existing Creative Inventory

Use these assets as the source set for experiment planning:

| Asset | Current role | Route-first use | EXIF-first use |
| --- | --- | --- | --- |
| `marketing-screenshots/01-route-list.png` | Saved route library | Shows retained trip history and revisit value. | Secondary proof that stamped-photo users can later organize trips. |
| `marketing-screenshots/02-route-map.png` | Route map result | Primary first frame for route reconstruction value. | Secondary route-analysis CTA proof after EXIF export. |
| `marketing-screenshots/03-timeline.png` | Timeline detail | Supports map result with chronological memory review. | Secondary proof of richer trip record. |
| `marketing-screenshots/04-exif-frame.png` | Stamped output | Secondary proof that route users can share visual records. | Primary first frame for stamped-photo output. |
| `marketing-screenshots/05-exif-theme.png` | EXIF theme picker | Optional second EXIF frame for customization value. | Primary support frame for creative control. |
| `marketing-screenshots/06-original-preview.png` | Original preview | Trust and before/after context. | Secondary proof that original photos remain inspectable. |

## Audience Frames

### Route-first

- Audience: travelers, walkers, local explorers, and photo-library users who want old trip photos turned into a map and timeline.
- Job to be done: "I have travel photos and want to see where I went without manually building a route."
- First impression goal: make the map route and timeline result visible before secondary utility screens.
- Copy direction:
  - "Turn travel photos into a route map."
  - "Rebuild trips from photo metadata."
  - "Review your day as a map and timeline."

### EXIF-first

- Audience: camera users, creators, bloggers, and social sharers who want a clean image with date, location, and camera context.
- Job to be done: "I want to export a shareable photo frame that preserves the story around the shot."
- First impression goal: make the finished EXIF-stamped image visible before route-library screens.
- Copy direction:
  - "Create clean EXIF-stamped travel images."
  - "Share photo context without editing by hand."
  - "Choose a stamp style, preview, then save or share."

## Experiment 1: Default Product Page Screenshot Order

### Hypothesis

Route-first ordering will improve default product page conversion because the route map communicates PhotoRava's broadest differentiator faster than the saved library or EXIF customization screens. EXIF-first ordering may perform better if store visitors arrive with camera/share intent rather than route reconstruction intent.

### Audience

- Default App Store visitors from search, browse, profile links, and general organic traffic.
- Primary frame: Route-first because the app's default tab and README product snapshot lead with route analysis.
- Secondary frame: EXIF-first as a challenger for users who understand stamped-photo output faster than route reconstruction.

### Creative Changes

Control screenshot order:

1. `marketing-screenshots/01-route-list.png`
2. `marketing-screenshots/02-route-map.png`
3. `marketing-screenshots/03-timeline.png`
4. `marketing-screenshots/04-exif-frame.png`
5. `marketing-screenshots/05-exif-theme.png`
6. `marketing-screenshots/06-original-preview.png`

Treatment A, Route-first result order:

1. `marketing-screenshots/02-route-map.png`
2. `marketing-screenshots/03-timeline.png`
3. `marketing-screenshots/01-route-list.png`
4. `marketing-screenshots/04-exif-frame.png`
5. `marketing-screenshots/05-exif-theme.png`
6. `marketing-screenshots/06-original-preview.png`

Treatment B, EXIF-first output order:

1. `marketing-screenshots/04-exif-frame.png`
2. `marketing-screenshots/05-exif-theme.png`
3. `marketing-screenshots/06-original-preview.png`
4. `marketing-screenshots/02-route-map.png`
5. `marketing-screenshots/03-timeline.png`
6. `marketing-screenshots/01-route-list.png`

Planned screenshot caption direction, if captions are added later:

- Route-first: "PhotoRava", "사진으로 경로 만들기", "지도와 타임라인으로 여행 복원".
- EXIF-first: "PhotoRava", "EXIF 스탬프 만들기", "사진 정보까지 깔끔하게 공유".

### Metric

Primary success metric: product page conversion rate from product page views to first-time downloads in App Analytics.

Secondary diagnostic metrics:

- Impression-to-product-page view rate by source, if available.
- First-time download volume normalized by traffic allocation.
- Downstream activation proxy from Todo 1, once local or approved analytics exists: first `analysis_complete`, `exif_save_complete`, or `exif_share_complete`.

### Minimum Run Rule

- Run for at least 14 full days and through one weekend cycle.
- Do not decide before Apple reports enough data to compare treatments, unless a treatment has a severe brand, localization, or asset-quality issue.
- Avoid overlapping screenshot-order tests with app version launches or paid acquisition changes that would make the result unreadable.

### Rollback / Apply Decision

- Apply Treatment A if it beats control on product page conversion and does not reduce EXIF activation proxy once downstream measurement exists.
- Apply Treatment B if it beats both control and Treatment A on product page conversion, then plan a route-first Custom Product Page to avoid losing route-analysis intent.
- Rollback to the control order if neither challenger improves conversion, if results are inconclusive after a normal run, or if qualitative review shows the first frame does not explain the product clearly.

## Experiment 2: Custom Product Page By Audience

### Hypothesis

Audience-specific Custom Product Pages will improve conversion from targeted links because each page can lead with the user's primary job: route reconstruction for trip-memory users, or EXIF-stamped output for creator/share users.

### Audience

- Route-first page: travel blogs, walking/cycling communities, portfolio links focused on route reconstruction, and posts that mention map/timeline results.
- EXIF-first page: camera communities, creator bios, social posts, and links focused on clean stamped-photo sharing.

### Creative Changes

Route-first Custom Product Page:

1. `marketing-screenshots/02-route-map.png`
2. `marketing-screenshots/03-timeline.png`
3. `marketing-screenshots/01-route-list.png`
4. `marketing-screenshots/04-exif-frame.png`
5. `marketing-screenshots/06-original-preview.png`

Promotional text direction:

- "Travel photos become a route map, timeline, and share-ready memory."
- Korean localization candidate: "여행 사진을 지도 경로와 타임라인으로 복원하세요."

EXIF-first Custom Product Page:

1. `marketing-screenshots/04-exif-frame.png`
2. `marketing-screenshots/05-exif-theme.png`
3. `marketing-screenshots/06-original-preview.png`
4. `marketing-screenshots/02-route-map.png`
5. `marketing-screenshots/03-timeline.png`

Promotional text direction:

- "Create clean EXIF-stamped images, then reuse the same photos for route analysis."
- Korean localization candidate: "사진 정보가 담긴 스탬프 이미지를 만들고, 같은 사진으로 경로도 분석하세요."

### Metric

Primary success metric: Custom Product Page conversion rate by page URL source.

Secondary diagnostic metrics:

- Product page views and first-time downloads by route-first vs EXIF-first link placement.
- Source quality notes for each link placement, kept separate from product changes.
- Future activation match from Todo 1: route-first links should over-index on `analysis_complete`; EXIF-first links should over-index on `exif_save_complete` or `exif_share_complete`.

### Minimum Run Rule

- Keep each audience page active for at least 21 full days or until each page has enough traffic to make a decision without one-off link spikes dominating the result.
- Compare audience pages only against comparable link sources. Do not compare a high-intent creator bio link against a broad search visitor segment.
- Do not change page copy, screenshot order, or link placement mid-run except to correct a broken or misleading asset.

### Rollback / Apply Decision

- Apply the Route-first page as the preferred route-analysis landing page if it improves conversion for route-intent links and downstream activation does not skew away from `analysis_complete`.
- Apply the EXIF-first page as the preferred creator/share landing page if it improves conversion for EXIF-intent links and downstream activation does not skew away from `exif_save_complete` or `exif_share_complete`.
- Rollback a page to the default product page link if conversion underperforms its source baseline, if the traffic source does not match the page framing, or if reviewers find the page promise broader than the current app.

## Measurement Notes

- The Todo 1 event taxonomy defines downstream activation as first successful `analysis_complete`, `exif_save_complete`, or `exif_share_complete`.
- App Store metrics can measure acquisition. They cannot prove in-app activation until a separately approved implementation adds compliant local or remote measurement.
- Do not use photo contents, precise coordinates, OCR text, route names, filenames, asset identifiers, or EXIF dictionaries in acquisition or activation analysis.

## Preflight Checklist For Later Console Work

- Confirm the existing screenshots still match the current app UI.
- Confirm Korean and English copy claims match implemented product behavior.
- Confirm any App Store-specific dimensions and localization requirements before preparing final files.
- Keep production AdMob IDs, analytics secrets, and private campaign tokens out of the repository.
- Record console work separately if a later task authorizes it; this brief is preparation only.
