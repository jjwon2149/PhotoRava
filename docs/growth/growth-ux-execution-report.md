# Growth UX Execution Report

## Shipped Changes

This report closes Todo 10 for `.omo/plans/growth-ux-roadmap.md`. It summarizes the roadmap execution state from Todos 1-9 and does not add product code, SDKs, console configuration, payment behavior, or remote measurement.

| Area | Shipped outcome | Primary artifacts |
| --- | --- | --- |
| Funnel taxonomy | Defined privacy-safe visit, start, activation, revisit, share, and payment-intent events with local debug-event payload rules. | `docs/growth/event-taxonomy.md`, `.omo/evidence/task-1-growth-ux-roadmap/qa.txt` |
| Home first-use clarity | Updated route home empty-state value copy and primary route creation CTA so the first screen explains map, timeline, and EXIF output. | `.omo/evidence/task-2-growth-ux-roadmap/home-empty.png`, `.omo/evidence/task-2-growth-ux-roadmap/home-empty-accessibility.png` |
| Photo selection guidance | Added beginner guidance, selected-count context, GPS/OCR fallback explanation, and zero-selection disabled-state help. | `.omo/evidence/task-3-growth-ux-roadmap/photo-empty.png`, `.omo/evidence/task-3-growth-ux-roadmap/photo-zero-disabled.png`, `.omo/evidence/task-3-growth-ux-roadmap/photo-selected-app-grid.png` |
| Analysis progress and recovery | Improved loading copy, processed-count context, local-processing reassurance, cancel semantics, and retry/select-again/dismiss recovery. | `.omo/evidence/task-4-growth-ux-roadmap/analysis-loading.png`, `.omo/evidence/task-4-growth-ux-roadmap/analysis-complete.png`, `.omo/evidence/task-4-growth-ux-roadmap/analysis-error-or-permission-recovery.png` |
| EXIF to route loop | Strengthened EXIF first-use copy and persistent post-export route-analysis CTA conditions without changing renderer/file-format behavior. | `.omo/evidence/task-5-growth-ux-roadmap/exif-empty.png`, `.omo/evidence/task-5-growth-ux-roadmap/qa-notes.md` |
| Search and settings recovery | Added search-empty recovery actions and friendlier Settings permission/diagnostic copy. | `.omo/evidence/task-6-growth-ux-roadmap/search-empty.png`, `.omo/evidence/task-6-growth-ux-roadmap/settings.png` |
| Acquisition experiments | Prepared App Store screenshot-order and audience-specific page experiment brief using existing marketing screenshots. | `docs/growth/app-store-experiments.md`, `.omo/evidence/task-7-growth-ux-roadmap/qa.txt` |
| Revisit/share/rating/payment-intent rules | Defined future prompt timing and suppression rules, with payment intent limited to interest measurement. | `docs/growth/revisit-share-rules.md`, `.omo/evidence/task-8-growth-ux-roadmap/qa.txt` |
| Funnel QA evidence | Built the app and captured partial route/EXIF/settings evidence; full Todo 9 capture coverage was waived by the user. | `.omo/evidence/task-9-growth-ux-roadmap/qa-notes.md`, `.omo/evidence/task-9-growth-ux-roadmap/adversarial.md` |

## Metrics

| Funnel stage | Ready metric | Source event or rule | Current implementation state |
| --- | --- | --- | --- |
| Visit | Visits by entry surface and saved-route availability. | `app_visit` | Taxonomy only; no SDK or upload implementation. |
| Route start | Visit-to-route-start and picker-open conversion. | `route_start_tap`, `photo_picker_open`, `analysis_start` | UI copy is ready for later local debug instrumentation. |
| Activation | First route analysis completion or EXIF save/share completion. | `analysis_complete`, `exif_save_complete`, `exif_share_complete` | Defined as the activation anchor; not remotely instrumented. |
| Recovery | Analysis error category and recovery option presentation. | `analysis_error` | Copy and alert recovery are implemented; metric remains local-contract only. |
| Revisit | Saved-route open rate after routes exist. | `revisit_saved_route` | Rule defined; no prompt or telemetry implementation. |
| Share | Share intent and EXIF share completion after user-created output. | `share_intent`, `exif_share_complete` | Rule defined; no new share analytics implementation. |
| Payment intent | Future non-purchasing interest signal after value is understood. | `payment_intent_placeholder` | Placeholder only; no payment, paywall, or StoreKit behavior. |
| Acquisition | Product-page conversion, Custom Product Page conversion, and downstream activation proxy after approved measurement exists. | `docs/growth/app-store-experiments.md` | Experiment brief only; no console work performed. |

## Evidence

| Scenario | Invocation or binary observable | Captured artifact |
| --- | --- | --- |
| Todo 1 taxonomy marker check | `rg -n "app_visit|analysis_complete|payment_intent_placeholder|No remote analytics SDK" docs/growth/event-taxonomy.md` | `.omo/evidence/task-1-growth-ux-roadmap/qa.txt` |
| Todo 2 home empty visual QA | Simulator screenshots plus `BUILD SUCCEEDED` evidence. | `.omo/evidence/task-2-growth-ux-roadmap/home-empty.png`, `.omo/evidence/task-2-growth-ux-roadmap/build-summary.txt` |
| Todo 3 picker states | Simulator screenshots for empty, zero-disabled, and selected-grid states. | `.omo/evidence/task-3-growth-ux-roadmap/photo-empty.png`, `.omo/evidence/task-3-growth-ux-roadmap/photo-zero-disabled.png`, `.omo/evidence/task-3-growth-ux-roadmap/photo-selected-app-grid.png` |
| Todo 4 route analysis states | Simulator screenshots for loading, completion handoff, small-device loading, and error alert; build log contains `BUILD SUCCEEDED`. | `.omo/evidence/task-4-growth-ux-roadmap/analysis-loading.png`, `.omo/evidence/task-4-growth-ux-roadmap/analysis-complete.png`, `.omo/evidence/task-4-growth-ux-roadmap/analysis-loading-small.png`, `.omo/evidence/task-4-growth-ux-roadmap/analysis-error-or-permission-recovery.png` |
| Todo 5 EXIF first-use state | Simulator screenshot plus source/build verification for post-export persistent CTA conditions. | `.omo/evidence/task-5-growth-ux-roadmap/exif-empty.png`, `.omo/evidence/task-5-growth-ux-roadmap/build-summary.txt` |
| Todo 6 search/settings recovery | Simulator screenshots for search-empty and normal Settings, plus source verification for denied-state recovery mapping. | `.omo/evidence/task-6-growth-ux-roadmap/search-empty.png`, `.omo/evidence/task-6-growth-ux-roadmap/settings.png`, `.omo/evidence/task-6-growth-ux-roadmap/qa-notes.md` |
| Todo 7 acquisition docs QA | Positive section marker scan and forbidden external-action scan. | `.omo/evidence/task-7-growth-ux-roadmap/qa.txt` |
| Todo 8 revisit/share rules QA | Positive rule marker scan and forbidden monetization/rating implementation scan. | `.omo/evidence/task-8-growth-ux-roadmap/qa.txt` |
| Todo 9 partial funnel QA | Build log and partial screenshots for home, photo selection, EXIF export, and Settings; actual analysis progress/loading and completion were not captured in Todo 9. | `.omo/evidence/task-9-growth-ux-roadmap/build-summary.txt`, `.omo/evidence/task-9-growth-ux-roadmap/home-empty.png`, `.omo/evidence/task-9-growth-ux-roadmap/photo-selection.png`, `.omo/evidence/task-9-growth-ux-roadmap/exif-export.png`, `.omo/evidence/task-9-growth-ux-roadmap/settings.png` |

## Risks

- Todo 9 is not full visual coverage. The user explicitly waived the remaining capture QA with "캡처qa는 스킵해", so this report records partial evidence and unverified states instead of claiming a complete simulator matrix.
- Runtime accessibility-tree inspection was not available in the captured evidence; accessibility conclusions are based on visible screenshots and source checks.
- Todo 5 post-export EXIF result screenshots were not captured; persistent CTA behavior was verified by source paths and build evidence.
- Todo 6 denied Settings screenshot automation did not land on the denied Settings state; source mapping and normal Settings screenshots support the state, but the Todo 9 denied capture is still unverified.
- The worktree remains dirty from prior roadmap tasks and evidence. This report does not resolve commit hygiene or mark plan checkboxes.
- Build warnings were documented in prior evidence and were not addressed by this docs-only report.

## Deferred / Unverified

- Todo 9 did not capture actual analysis progress/loading or completion. `.omo/evidence/task-9-growth-ux-roadmap/analysis-loading.png` shows the zero-selection photo picker sheet, so it is not valid analysis loading evidence.
- Todo 9 `analysis-complete.png` was not captured in Todo 9. Todo 4 has supporting `analysis-complete.png`, but it is not counted as Todo 9 full capture coverage.
- Todo 9 `home-empty-small-accessibility.png` was not captured in Todo 9. Todo 2 has supporting accessibility screenshots, but they do not replace the waived Todo 9 capture.
- Todo 9 `settings-denied.png` was not captured in Todo 9. Todo 6 includes supporting denied-state source verification and earlier screenshot attempts, but Todo 9 did not produce this required capture.
- Some supporting screenshots exist from Todo 4 and Todo 6, but Todo 9 full capture coverage was waived by the user.
- App Store experiment execution, Custom Product Page setup, analytics SDK selection, remote event upload, release ad configuration, rating prompts, Apple purchase-framework work, payment UI, and paywall work are all deferred.
- Payment intent remains a future placeholder metric only.

## Next Experiments

1. Run one App Store screenshot-order experiment after approved console access and current screenshots are revalidated.
2. Prepare separate route-first and EXIF-first Custom Product Page assets only after the default product page experiment has a baseline.
3. Add a local debug-event implementation for the Todo 1 taxonomy in a separate approved task before comparing in-app activation cohorts.
4. Re-run the full Todo 9 simulator capture matrix if visual coverage becomes required again, starting with `analysis-complete.png`, `home-empty-small-accessibility.png`, and `settings-denied.png`.
5. Consider a dedicated refactor task for oversized route-analysis and EXIF views before adding more UX states.
