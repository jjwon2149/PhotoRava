# Growth Event Taxonomy

## Scope

This taxonomy defines PhotoRava's privacy-safe growth funnel before any product instrumentation is implemented. It covers visit, start, activation, revisit, share, and payment-intent measurement for the route analysis and EXIF stamp flows.

No remote analytics SDK in this plan.

This plan does not select Firebase, GA4, StoreKit analytics, an ad network analytics product, or any remote upload destination. Later implementation may emit local debug events that match this contract, but it must not add third-party analytics or network transmission without a separate approved task.

## Privacy Rules

- Events may use coarse counts, buckets, booleans, enum categories, app/build context, and non-identifying session IDs generated for local debugging.
- Events must not include photo contents, latitude/longitude, OCR strings, route titles, camera/image metadata fields, EXIF dictionaries, filenames, asset identifiers, addresses, or user-entered names.
- Error events should use coarse categories such as `permission_denied`, `no_readable_metadata`, `processing_failed`, `save_failed`, `share_cancelled`, or `unknown`.
- Duration values should be bucketed, for example `under_5s`, `5_30s`, `30_120s`, or `over_120s`.
- Count values should be bucketed, for example `0`, `1`, `2_4`, `5_20`, or `over_20`.

## Local Debug-Event Payload Shape

The local-only debug payload should be easy to print to the Xcode console, write to an in-memory debug panel, or inspect in a local development log without committing to a third-party SDK.

```json
{
  "event_name": "analysis_complete",
  "occurred_at": "2026-07-01T12:00:00Z",
  "schema_version": 1,
  "app_context": {
    "app_version": "local-build",
    "build_number": "local",
    "platform": "iOS",
    "os_major_version": 17,
    "interface_language": "ko"
  },
  "debug_context": {
    "local_session_id": "ephemeral-uuid",
    "source_screen": "analysis_progress",
    "is_debug_event": true
  },
  "parameters": {
    "selected_photo_count_bucket": "5_20",
    "duration_bucket": "30_120s",
    "used_ocr_recovery": true
  }
}
```

Required implementation constraints for this payload:

- `local_session_id` must be resettable and must not be a device identifier, Apple advertising identifier, photo asset identifier, contact identifier, or account identifier.
- `parameters` must follow the event-specific allowlist below.
- Debug output must remain local unless a later approved plan explicitly chooses a remote analytics implementation and repeats privacy review.

## Funnel Events

| Event name | Trigger | Parameters | Privacy classification | Funnel stage | Success metric |
| --- | --- | --- | --- | --- | --- |
| `app_visit` | App foregrounds into the main tab shell or first visible screen during a local debug session. | `entry_surface` enum: `route_list`, `exif_tab`, `settings`, `unknown`; `has_saved_route` boolean; `launch_type` enum: `cold`, `warm`, `unknown`. | Local debug, non-sensitive app state only. | Visit | Count of local debug visits and share of visits with a saved route available. |
| `route_start_tap` | User taps a route-analysis start CTA from home, empty state, search recovery, or a post-EXIF route-analysis prompt. | `source_screen` enum; `source_component` enum: `primary_cta`, `toolbar_plus`, `empty_state`, `search_empty`, `exif_result`; `has_saved_route` boolean. | Local debug, UI interaction only. | Start | Visit-to-route-start conversion rate. |
| `photo_picker_open` | Photo selection UI is presented for route analysis. | `source_screen` enum; `authorization_state` enum: `not_determined`, `limited`, `authorized`, `denied`, `restricted`, `unknown`; `selection_mode` enum: `route_analysis`. | Local debug, coarse permission state only. | Start | Route-start-to-picker-open completion rate. |
| `analysis_start` | User starts route analysis with at least one selected photo. | `selected_photo_count_bucket`; `authorization_state` enum; `source_screen` enum; `has_existing_routes` boolean. | Local debug, coarse selection count only. | Start | Picker-open-to-analysis-start conversion rate. |
| `analysis_complete` | Route analysis finishes and a route is saved/opened. | `selected_photo_count_bucket`; `processed_photo_count_bucket`; `duration_bucket`; `used_ocr_recovery` boolean; `route_point_count_bucket` using coarse counts only. | Local debug, derived coarse counts only. | Activation | Analysis-start-to-complete rate and first route activation rate. |
| `analysis_error` | Route analysis cannot complete or exits with a recoverable failure. | `selected_photo_count_bucket`; `duration_bucket`; `error_category`; `recovery_presented` enum: `retry`, `select_again`, `settings`, `dismiss`, `unknown`. | Local debug, coarse error category only. | Activation recovery | Error rate by category and recovery option presentation rate. |
| `exif_start` | User opens or starts the EXIF stamp flow from the EXIF tab or another CTA. | `source_screen` enum; `source_component` enum; `has_selected_photo` boolean; `mode` enum: `single`, `batch`, `unknown`. | Local debug, UI state only. | Start | Visit-to-EXIF-start conversion rate. |
| `exif_save_complete` | Stamped image save or batch export completes successfully. | `mode` enum: `single`, `batch`; `selected_photo_count_bucket`; `duration_bucket`; `output_action` enum: `save`; `route_analysis_cta_visible` boolean. | Local debug, coarse counts and action only. | Activation | EXIF-start-to-save activation rate. |
| `exif_share_complete` | Share sheet returns after a successful EXIF stamped image share attempt. | `mode` enum: `single`, `batch`; `selected_photo_count_bucket`; `output_action` enum: `share`; `share_result` enum: `completed`, `cancelled`, `unknown`. | Local debug, coarse share result only. | Share | EXIF-start-to-share completion rate. |
| `revisit_saved_route` | User opens an existing saved route from the route list, search results, or a deep local navigation path. | `source_screen` enum: `route_list`, `search_results`, `unknown`; `days_since_last_visit_bucket` enum: `same_day`, `1_7`, `8_30`, `over_30`, `unknown`; `has_multiple_routes` boolean. | Local debug, coarse revisit timing only. | Revisit | Saved-route open rate among visits with saved routes. |
| `share_intent` | User taps a share CTA for a route summary, route snapshot, EXIF output, or future share surface before the platform sheet result is known. | `source_screen` enum; `share_surface` enum: `route_summary`, `route_snapshot`, `exif_output`, `unknown`; `has_user_created_output` boolean. | Local debug, UI interaction only. | Share | Activated-user share intent rate. |
| `payment_intent_placeholder` | User taps a future, non-purchasing interest signal for a paid feature concept after monetization strategy exists. This is a placeholder only. | `source_screen` enum; `interest_surface` enum: `future_export_pack`, `future_theme_pack`, `future_pro_feature`, `unknown`; `user_action` enum: `learn_more`, `notify_me`, `dismissed`. | Local debug, interest signal only; no StoreKit, price, or billing data. | Payment intent | Future interest rate among activated users; not revenue or purchase conversion. |

## Stage Metrics

- Visit: `app_visit` volume and saved-route availability.
- Start: `route_start_tap`, `photo_picker_open`, `analysis_start`, and `exif_start` conversion.
- Activation: first successful `analysis_complete`, `exif_save_complete`, or `exif_share_complete`.
- Revisit: `revisit_saved_route` after a saved route exists.
- Share: `share_intent` and `exif_share_complete` after user-created output exists.
- Payment intent: `payment_intent_placeholder` only as future interest measurement, with no purchase flow.

## Implementation Guardrails

- Do not add analytics SDK initialization, event-upload code, network destinations, secrets, or build settings for analytics in this plan.
- Do not add product-code logging as part of this docs task.
- Do not persist local debug events in SwiftData models or modify `Route` or `PhotoRecord`.
- Do not infer private content from selected photos for analytics. Use only the allowlisted, coarse parameters in this document.
