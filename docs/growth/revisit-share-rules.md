# Revisit, Share, Rating, and Payment-Intent Rules

## Scope

This document defines product rules for future revisit prompts, share prompts, App Store rating timing, and payment intent measurement in PhotoRava. It is a docs-only guardrail for the growth UX roadmap.

No code, StoreKit integration, system rating API call, paywall, subscription, paid feature interface, analytics SDK, or product UI is added by this task.

These rules build on `docs/growth/event-taxonomy.md` and its local-only events: `revisit_saved_route`, `share_intent`, `exif_share_complete`, and `payment_intent_placeholder`.

## Shared Principles

- Ask only after the user has created value in the app, never before they understand what PhotoRava made for them.
- Do not interrupt first-use setup, permission decisions, photo selection, analysis progress, export progress, or error recovery.
- Use existing user-created outputs as the trigger: a saved route, a generated route snapshot, a saved EXIF-stamped image, or a successfully prepared EXIF share item.
- Keep measurement privacy-safe. Use only coarse counts, booleans, enum surfaces, and coarse timing buckets already allowed by the event taxonomy.
- If the same session has an error, cancellation, permission denial, or no generated output, suppress revisit, share, rating, and payment intent prompts for that session.

## Revisit Rules

Revisit prompts exist to help users return to their own saved routes. They are not onboarding and are not ads.

Eligible scenarios:

- The user launches or foregrounds the app and has at least one saved route.
- The user has not already opened a saved route in the current session.
- The route list is visible and not covered by a modal, permission sheet, share sheet, or error alert.
- The prompt can point to an actual saved route or route list action without exposing private route names in analytics.

Allowed surfaces:

- Route list header or empty-search recovery copy.
- A non-blocking saved-route reminder near the route list.
- A contextual "최근 경로 다시 보기" action when saved routes exist.

Suppression rules:

- Do not show on first launch before any successful route analysis or EXIF output exists.
- Do not show during onboarding-like first-use education, photo picker presentation, analysis, export, or permission recovery.
- Do not show more than once per local day in future implementation.
- Do not show after the user dismissed the same revisit suggestion in the current session.

Measurement:

- Record `revisit_saved_route` only when the user opens an existing route.
- Allowed parameters are limited to `source_screen`, `days_since_last_visit_bucket`, and `has_multiple_routes`.
- Do not record route names, coordinates, addresses, filenames, photo contents, or image metadata.

## Share Rules

Share prompts happen only after successful user-created output. A share prompt must never appear before a route snapshot, route summary, or EXIF-stamped output is actually available.

Eligible scenarios:

- Route analysis has completed and the route detail or route map can generate a route snapshot or summary.
- A route snapshot save succeeds, making a concrete visual output available.
- A single EXIF-stamped image has rendered and can be shared.
- Batch EXIF export has produced at least one successful output URL or saved result.

Allowed surfaces:

- Existing route detail or route map share action after the route is saved and visible.
- Existing EXIF export share action after render/export success.
- A post-success result area that offers sharing as a next action without blocking continued editing.

Suppression rules:

- Do not ask to share if analysis failed, export failed, permission was denied, or the user cancelled the operation.
- Do not ask to share during loading, while a batch export is running, or while the system share sheet is already open.
- Do not prompt for sharing based only on selected photos; there must be a successful app-created output.
- Do not show repeated share prompts after the user has dismissed one in the same session.

Measurement:

- Record `share_intent` when the user taps a share CTA before the system sheet result is known.
- Record `exif_share_complete` only for EXIF share completion or cancellation as allowed by the taxonomy.
- Include `has_user_created_output = true` only when the output exists; otherwise do not emit the share event.
- Do not infer social network, recipient, message content, exact file metadata, coordinates, or OCR text.

## Rating Rules

The rating prompt is never shown on first launch/onboarding. It should be considered only after a user has had repeated successful outcomes and is not in an interrupted or fragile state.

Minimum eligibility for a future implementation:

- The user has completed at least two successful value moments across route analysis and EXIF output, such as `analysis_complete`, `exif_save_complete`, or `exif_share_complete`.
- At least one success happened in a previous session, so the request is not attached to the first activation moment.
- The current session has no active error, permission denial, cancellation, or in-progress export/analysis task.
- The user is on a stable completion or review surface, such as a saved route detail, route map, or EXIF result state.

Suppression rules:

- Never show on first launch, onboarding-like first-use copy, first photo selection, first analysis start, first EXIF start, or first successful output.
- Do not show immediately after an error, failed save, cancelled share, denied permission, or app relaunch from Settings.
- Do not show if the user has just been asked to share or revisit in the same session.
- Respect all future platform frequency limits and any local "dismissed" cooldown.

Measurement:

- This docs task does not add rating telemetry beyond the existing local debug-event taxonomy.
- If future work adds local measurement, it should track coarse eligibility and dismissal state only, not review text, star rating, Apple account state, or App Store identity.

## Payment-Intent Rules

Payment intent is measured only as user interest, not monetization implementation. It is not a purchase flow, billing flow, subscription start, paid feature gate, or revenue metric.

Eligible future interest signals:

- The user taps a non-purchasing "learn more" or "notify me" style control for a possible future export pack, theme pack, or pro feature concept.
- The user has already completed at least one successful route or EXIF output, so the concept is grounded in an understood value.
- The control clearly communicates that it is an interest signal and does not unlock paid functionality.

Suppression rules:

- Do not collect payment intent on first launch, onboarding, permission prompts, error recovery, or before any successful user-created output.
- Do not display prices, checkout UI, subscription language, billing confirmation, paid gates, trial language, or locked core actions in this roadmap task.
- Do not treat interest taps as revenue, conversion, purchase readiness, or willingness to pay.

Measurement:

- Use `payment_intent_placeholder` only as a local debug-event placeholder if a later approved task creates a non-purchasing interest control.
- Allowed parameters remain `source_screen`, `interest_surface`, and `user_action`.
- Do not collect billing data, price points, payment identifiers, Apple account information, precise route/photo data, or user-entered personal data.

## Implementation Boundaries

- This task creates only `docs/growth/revisit-share-rules.md` and task evidence.
- No StoreKit capability, rating API call, paid feature UI, paywall, product Swift change, project setting change, Info.plist change, AdMob change, asset change, or remote analytics behavior is implemented.
- Future implementation must be separately approved and must re-check these rules against Apple platform guidance and PhotoRava's privacy posture.
